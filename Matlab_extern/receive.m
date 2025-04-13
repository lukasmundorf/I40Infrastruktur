function receive
%% Hauptskript
clc;
daqreset;  % Setzt das gesamte DAQ-Subsystem zurück
clear;
warning('off', 'all') % Warning-Messages abschatlen
% Vorherige Timer löschen (falls vorhanden)
oldTimers = timerfind;
if ~isempty(oldTimers)
    delete(oldTimers);
end
if exist('handles','var') && isfield(handles, 'd') && ~isempty(handles.d)
    try
        release(handles.d);
    catch
        clear handles.d;
    end
end

% --- Initialisierung ---
% Erstelle das Data Acquisition Objekt (neues Objekt, nicht session)
handles.d = daq('dt');
% Hinweis: Hier können bei Bedarf erste Eingänge konfiguriert werden, falls nötig:
% handles.d.addinput("DT9836(00)", 0, "Voltage");

% MQTT-Broker-Adresse und Topics:
handles.mqttClient = mqttclient("tcp://localhost:1884");
handles.topic = "control/measurement";    % Für Steuerbefehle
handles.dataTopic = "data/raw/sensor";    % Für das Senden von Daten

% Verbindung prüfen und Topics abonnieren
disp("Verbindung hergestellt: " + string(handles.mqttClient.Connected));
subscribe(handles.mqttClient, handles.topic);
disp("Abonniert auf das Topic: " + handles.topic);

% Variable zur Steuerung des Messstatus (false = nicht messen, true = messen)
handles.isMeasuring = false;
% Variable, in der der zuletzt gültige Zustand gespeichert wird
handles.lastFilteredData = [];
% Puffer für Messdaten (wird im Datenversand verwendet)
handles.measurementBuffer = [];
% Timer-Handle (wird später erstellt)
handles.measurementTimer = [];
% Paketgröße: Anzahl Scans, die pro gesendetem Paket zusammengefasst werden sollen
handles.numPointsThreshold = 1000;
%Zusätzlicher Wert zur Umrechnung von ms in ns
msToNs = 1000000;

% --- Hauptschleife zur Steuerung über MQTT ---
while true
    % Lese Nachrichten vom Control-Topic (Timeout z.B. 5 Sekunden)
    messages = read(handles.mqttClient, 'Topic', handles.topic);

    if ~isempty(messages)
        for i = 1:height(messages)
            payload = string(messages.Data(i));
            disp(datetime("now", TimeZone="UTC"));
            data = jsondecode(payload);

            fprintf("\n--- Originale Nachricht ---\n");
            fprintf("Start/Stop Status: %s\n", data.startStop);
            fprintf("Abtastrate (Hz): %d\n", data.abtastrateHz);
            fprintf("Messungsname: %s\n", data.measurementName);
            fprintf("Channels: %s\n", strjoin(data.channel, ", "));
            fprintf("Einheiten: %s\n", strjoin(data.einheit, ", "));
            fprintf("Messrichtungen: %s\n", strjoin(data.messrichtung, ", "));
            fprintf("Notizen: %s\n", strjoin(data.notizen, ", "));
            fprintf("MeasuredQuantity: %s\n", strjoin(data.measuredQuantity, ", "));
            fprintf("Sensitivitäten: %s\n", mat2str(data.sensiArray));

            % Prüfe, ob der empfangene Befehl dem aktuellen Status entspricht
            if strcmpi(data.startStop, "start") && handles.isMeasuring
                fprintf("\nMessung läuft bereits, 'start' wird ignoriert.\n");
                if ~isempty(handles.lastFilteredData)
                    dispLastFiltered();
                end
                continue;
            elseif strcmpi(data.startStop, "stop") && ~handles.isMeasuring
                fprintf("\nMessung ist bereits gestoppt, 'stop' wird ignoriert.\n");
                if ~isempty(handles.lastFilteredData)
                    dispLastFiltered();
                end
                continue;
            end

            % Bei 'start' den Zustand neu filtern und das DAQ-Objekt updaten:
            if strcmpi(data.startStop, "start")
                % Filtere die aktiven Channels von den leeren Strings in neuem Array channelNumbers:
                channels = data.channel;
                channelNumbers = [];
                for k = 1:length(channels)
                    if ~isempty(channels{k})
                        numStr = regexprep(channels{k}, '^ch', '');
                        numVal = str2double(numStr);
                        if ~isnan(numVal)
                            channelNumbers(end+1) = numVal;
                        end
                    end
                end

                % sortiere die aktiven Channels nach Ihrer Zahl
                channelNumbers = sort(channelNumbers);
                activeIdx = channelNumbers + 1;

                % Überschreibe die Arrays mit Informationen einzig mit
                % den Informationen, die aktive Channels beinhalten
                data.einheit      = data.einheit(activeIdx);
                data.messrichtung = data.messrichtung(activeIdx);
                data.notizen      = data.notizen(activeIdx);
                data.sensiArray   = data.sensiArray(activeIdx);
                data.measuredQuantity = data.measuredQuantity(activeIdx);
                data.channel = arrayfun(@(x) num2str(x), channelNumbers, 'UniformOutput', false);

                % ersetze alle leeren Strings in notizen durch 'none'
                emptyIdx = cellfun(@isempty, data.notizen);
                data.notizen(emptyIdx) = {'none'};


                % Verrechnung der Volts aus der Messkarte mit den Einheiten der Sensitivitätsfaktoren
                %
                % Erstelle einen "V" Array der Länge der Anzahl Aktiver Channels
                string_array = repmat(("V"), 1, length(activeIdx));
                symbolicUnits_tmp = str2symunit(string_array); % Alle VariableUnits aus tmp in symunit umwandeln
                % Felder innerhalb von Unit, die keine korrekten Einheiten beinhalten,
                % werden auf 1 gesetzt. Anschließend werden alle Felder in ein
                % symunit-Objekt umgewandelt.
                for i=1:length(data.einheit)
                    try
                        symbolicUnits_unit(i) = str2symunit(data.einheit(i));
                    catch
                        %warning('Die Einheit ''%s'' in der Varibale ''%s(%i)'' konnte nicht in eine symunit umgewandelt werden. Sie wurde stattdessen auf den Wert 1 gesetzt.', measurement_settings.SensitivityUnit(i), 'measurement_settings.SensitivityUnit', i)
                        data.einheit{i} = '1'; % Feld von Unit(i) auf 1 setzen, damit es in ein symunit-Objekt umgewandelt werden kann
                        symbolicUnits_unit(i) = str2symunit(data.einheit(i));
                    end
                end

                % Verrechnen der Sensitivitäten
                handles.isXoverV = arrayfun(@(x) contains(string(x), '/V') || ~isempty(regexp(string(x), '/.*V', 'once')), data.einheit); % Logische Indizes für "/V"
                handles.isVoverX = contains(string(data.einheit), 'V/'); % Logische Indizes für "V/"
                ergebnis = str2symunit(int2str(ones(length(symbolicUnits_unit),1)))'; % symunit-Array deklarieren mit lauter 1en je Feld
                ergebnis(:, handles.isXoverV) = symbolicUnits_tmp(:, handles.isXoverV) .* symbolicUnits_unit(handles.isXoverV); % Multiplikation für "x/V"
                ergebnis(:, handles.isVoverX) = symbolicUnits_tmp(:, handles.isVoverX) ./ symbolicUnits_unit(handles.isVoverX); % Division für "V/x"
                % Fertig berechnete Einheiten und entstandene Faktoren nach Verrechnung der Sensitivitätseinheiten Mit Spannung aus der Messkarte
                [handles.faktoren,units_temp]=separateUnits(ergebnis); %Faktoren und Einheiten trennen

                % Ermittelte finale Einheiten nach Verrechung der Sensititvitätseinheiten auf data.einheit überschreiben
                data.einheit = string(symunit2str(units_temp));

                % Namen der Zeitreihen aus MeasuredQuantity und Messrichtung ableiten
                % Richtungsangaben bereinigen (Vorzeichen entfernen und klein schreiben)
                formatted_direction = lower(replace(data.messrichtung, ["+", "-"], ""));
                has_direction = data.messrichtung ~= ""; % Logische Maske für nicht-leere Richtungen
                result = string(data.measuredQuantity);
                result(has_direction) = string(formatted_direction(has_direction)) + string(data.measuredQuantity(has_direction)); % Nur die Einträge mit Richtung kombinieren

                % Doppelte Strings in result hochnummerieren
                % Hochzählende Nummerierung für doppelte Strings
                [uniqueStrings, ~, idx] = unique(result, 'stable');
                counts = accumarray(idx, 1); % Zähle Vorkommen jedes einzigartigen Strings
                % Erstelle das finale Ergebnis mit Nummerierung
                finalResult = strings(size(result));
                for i = 1:length(uniqueStrings)
                    occurrences = find(idx == i);
                    if length(occurrences) > 1
                        finalResult(occurrences) = uniqueStrings(i) + "_" + string(1:length(occurrences));
                    else
                        finalResult(occurrences) = uniqueStrings(i);
                    end
                end

                data.channelnames = finalResult; % Neu gebildete Namen in data und damit auch handles abspeichern
                data.messrichtung(cellfun(@isempty, data.messrichtung)) = {'none'};

                %Ende der Berechnung der Faktoren und resultierenden Einheiten der umgerechneten Daten
                %

                % Aktualisiere im DAQ-Objekt die aktiven Kanäle:
                while ~isempty(handles.d.Channels)
                    handles.d.removechannel(1);
                end
                for ch = channelNumbers
                    handles.d.addinput("DT9836(00)", ch, "Voltage");
                end
                disp("Aktuell konfigurierte Channels im DAQ-Objekt:");
                disp(handles.d.Channels);

                % Setze die Abtastrate am DAQ-Objekt
                handles.d.Rate = data.abtastrateHz;
                % Speichere den gefilterten Zustand als letzten gültigen Stand
                handles.lastFilteredData = data;

                fprintf("\n--- Nachricht nach Kürzen und Verrechnung der Einheiten ---\n");
                fprintf("Start/Stop Status: %s\n", data.startStop);
                fprintf("Abtastrate (Hz): %d\n", data.abtastrateHz);
                fprintf("Messungsname: %s\n", data.measurementName);
                fprintf("Channels: %s\n", strjoin(data.channel, ", "));
                fprintf("ChannelNames: %s\n", strjoin(data.channelnames, ", "));
                fprintf("Einheiten: %s\n", strjoin(data.einheit, ", "));
                fprintf("Messrichtungen (noch nicht verrechnet): %s\n", strjoin(data.messrichtung, ", "));
                fprintf("Notizen: %s\n", strjoin(data.notizen, ", "));
                % fprintf("MeasuredQuantity: %s\n", strjoin(data.measuredQuantity, ", "));
                % fprintf("Sensitivitäten: %s\n", mat2str(data.sensiArray));
                fprintf("Aktuelle Abtastrate: %d Hz\n", handles.d.Rate);

                % Sende Metadaten per MQTT (über handles.dataTopic)
                sendMetadata();
                pause(1);

                % Starte das DAQ-Objekt und den Datenversand-Timer (alle 2 Sekunden)
                startMeasurement();
                handles.isMeasuring = true;
            end

            if strcmpi(data.startStop, "stop")
                stopMeasurement();
                handles.isMeasuring = false;
            end
        end
    end
    pause(0.5);
end

%% Funktion zum Senden der Metadaten
    function sendMetadata()
        % Diese Funktion erstellt für jeden aktiven Channel aus handles.lastFilteredData
        % ein JSON-Paket und sendet es per MQTT über handles.dataTopic.
        %
        % Es wird angenommen, dass handles.lastFilteredData folgende Felder enthält:
        %   - channel: Zellenarray mit Kanalnummern als Strings (z. B. {"0", "2", ...})
        %   - einheit, messrichtung, notizen: Zellenarrays
        %   - sensiArray: numerischer Array
        %   - measurementName: String
        %
        % Für den Zeitstempel verwenden wir die aktuelle Unixzeit in Millisekunden.
        metadata = handles.lastFilteredData;
        t = posixtime(datetime('now', TimeZone='UTC'));
        t_ms = round(t * 1000 * msToNs);

        % Für jeden Channel:
        for index = 1:length(metadata.channel)
            % Messrichtung: Falls ein "-" vorne steht, ersetze es durch "+"
            messrichtung_clean = metadata.messrichtung{index};
            if startsWith(messrichtung_clean, "-")
                messrichtung_clean = strcat("+", messrichtung_clean(2:end)); % Ersetzt "-" durch "+"
            end


            % Struct befüllen
            data_struct = struct(...
                'channelName', metadata.channelnames(index), ...
                'channelNumber', metadata.channel(index), ... % Nummerierung der Channels
                'time', t_ms + index, ...  % Leicht erhöhter Zeitstempel
                'messrichtung', messrichtung_clean, ... % Messrichtung ohne führendes "-"
                'notizen', metadata.notizen{index}, ...
                'measuredQuantity', metadata.measuredQuantity{index}, ...
                'einheit', metadata.einheit{index}, ...  % Wert 1 beschreibt "keine Einheit"
                'sampleRate', metadata.abtastrateHz, ...
                'dataType', 'matlabMetadata', ...
                'measurementName', metadata.measurementName);

            json_str = jsonencode(data_struct);
            disp(['Gesendete Metadaten: ', json_str]);
            write(handles.mqttClient, handles.dataTopic, json_str);
        end
    end

%% Verschachtelte Funktionen für Timer-Steuerung

% startMeasurement() startet das DAQ-Objekt und einen Timer, der alle 2 Sekunden sendData() aufruft.
    function startMeasurement()
        % Starte das DAQ-Objekt im kontinuierlichen Modus
        start(handles.d, "continuous");
        handles.triggerTime = datetime("now", TimeZone="UTC");
        pause(2);  % Warte 2 Sekunden, damit das DAQ-Objekt initial Daten sammeln kann

        if isempty(handles.measurementTimer) || ~isvalid(handles.measurementTimer)
            handles.measurementTimer = timer('ExecutionMode', 'fixedRate', ...
                'Period', 2, ...  % Alle 2 Sekunden
                'TimerFcn', @sendData);
            start(handles.measurementTimer);
        end
    end

% stopMeasurement() stoppt und löscht den Timer.
    function stopMeasurement()
        % Stoppe das DAQ-Objekt, damit keine weiteren Scans mehr erfolgen.
        stop(handles.d);
        disp('DAQ-Objekt gestoppt.');

        % Stoppe den Timer (falls er läuft)
        if ~isempty(handles.measurementTimer) && isvalid(handles.measurementTimer)
            stop(handles.measurementTimer);
            disp('Timer gestoppt.');
        end

        % Prüfe, ob noch Scans im DAQ-Puffer vorhanden sind.
        if handles.d.NumScansAvailable > 0
            disp('Flush: Zusätzliche Scans werden vom DAQ gelesen ...');
            ScanData = handles.d.read("all", "OutputFormat", "Timetable");
            if ~isempty(ScanData)

                % Sensitivitätswerte einrechnen
                ScanData(:, handles.isXoverV) = ScanData(:, handles.isXoverV) .* handles.lastFilteredData.sensiArray(handles.isXoverV)' .* double(handles.faktoren(handles.isXoverV)); % Multiplikation für "x/V", "faktoren" stammt aus der Umrechnung der Einheiten
                ScanData(:, handles.isVoverX) = ScanData(:, handles.isVoverX) ./ handles.lastFilteredData.sensiArray(handles.isVoverX)' .* double(handles.faktoren(handles.isVoverX)); % Division für "V/x", "faktoren" stammt aus der Umrechnung der Einheiten

                % Abhängig von dem Vorzeichen der Werte in measurement_settings.Direction
                % sollen die Zeitreiehen aus tmp_new mit -1 multipliziert werden
                negative_mask = startsWith(handles.lastFilteredData.messrichtung, "-"); % Logische Maske für alle Einträge mit negativem Vorzeichen ("-")
                ScanData(:, negative_mask) = ScanData(:, negative_mask) .* -1; % Multipliziere die betroffenen Spalten mit -1


                % Verarbeitung analog zur sendData()-Funktion:
                timeVec = posixtime(handles.triggerTime + ScanData.Time) * 1000 *msToNs;
                Ttime = table(int64(timeVec), 'VariableNames', {'time'});
                voltageData = table2array(ScanData);
                nChannels = size(voltageData, 2);

                % Verwende die aktiven Kanalnamen aus lastFilteredData für die Spaltennamen:
                Tvolt = array2table(voltageData, 'VariableNames', handles.lastFilteredData.channelnames);
                Tcombined = [Ttime, Tvolt];

                newData = table2struct(Tcombined, 'ToScalar', false);
                [newData.dataType] = deal("matlabData");
                [newData.measurementName] = deal(handles.lastFilteredData.measurementName);

                % Hänge die neuen Daten an den Buffer an:
                handles.measurementBuffer = [handles.measurementBuffer; newData(:)];
            else
                disp('Keine Scans zum Flush vorhanden.');
            end
        else
            disp('Keine zusätzlichen Scans verfügbar.');
        end

        % Sende den Buffer in Paketen der Größe handles.numPointsThreshold
        flushSize = handles.numPointsThreshold;
        while numel(handles.measurementBuffer) >= flushSize
            packet = handles.measurementBuffer(1:flushSize);
            handles.measurementBuffer(1:flushSize) = [];

            jsonStr = jsonencode(packet);
            write(handles.mqttClient, handles.dataTopic, jsonStr);
            fprintf('Gesendetes Datenpaket: %s\n', jsonStr);
        end

        % Falls noch weniger als flushSize übrig sind, sende diese als Rest.
        if ~isempty(handles.measurementBuffer)
            jsonStr = jsonencode(handles.measurementBuffer);
            write(handles.mqttClient, handles.dataTopic, jsonStr);
            fprintf('Gesendetes Restdatenpaket (Rest): %s\n', jsonStr);
        end

        % Jetzt Buffer explizit leeren, damit wirklich keine leeren Elemente übrig bleiben:
        handles.measurementBuffer = [];
        disp('Buffer komplett geleert.');

        % Lösche den Timer und setze den Timer-Handle zurück.
        if ~isempty(handles.measurementTimer) && isvalid(handles.measurementTimer)
            delete(handles.measurementTimer);
            disp('Timer gelöscht.');
            handles.measurementTimer = [];
        end
    end


% sendData() liest die Messdaten vom DAQ-Objekt ein, fügt sie einem Puffer hinzu und
% sendet in Paketen der vorgegebenen Größe (handles.numPointsThreshold) die Daten per MQTT.
    function sendData(~, ~)
        try
            pause(0.2);
            % Ausgabe des Bufferstatus vor dem Lesen:
            disp("Vor read: ");
            disp([handles.d.NumScansAvailable, handles.d.NumScansAcquired]);
            disp(datetime("now", TimeZone="UTC"));
            scans = handles.d.NumScansAvailable;

            conversionTime = tic;  % Start der Zeitmessung (read bis write)
            ScanData = handles.d.read("all", "OutputFormat", "Timetable");

            disp("Nach read: ");
            disp([handles.d.NumScansAvailable, handles.d.NumScansAcquired]);

            % Sensitivitätswerte einrechnen
            ScanData(:, handles.isXoverV) = ScanData(:, handles.isXoverV) .* handles.lastFilteredData.sensiArray(handles.isXoverV)' .* double(handles.faktoren(handles.isXoverV)); % Multiplikation für "x/V", "faktoren" stammt aus der Umrechnung der Einheiten
            ScanData(:, handles.isVoverX) = ScanData(:, handles.isVoverX) ./ handles.lastFilteredData.sensiArray(handles.isVoverX)' .* double(handles.faktoren(handles.isVoverX)); % Division für "V/x", "faktoren" stammt aus der Umrechnung der Einheiten

            % Abhängig von dem Vorzeichen der Werte in measurement_settings.Direction
            % sollen die Zeitreiehen aus tmp_new mit -1 multipliziert werden
            negative_mask = startsWith(handles.lastFilteredData.messrichtung, "-"); % Logische Maske für alle Einträge mit negativem Vorzeichen ("-")
            ScanData(:, negative_mask) = ScanData(:, negative_mask) .* -1; % Multipliziere die betroffenen Spalten mit -1

            % Berechne den Unix-Zeitstempel (in Millisekunden)
            %Erstellen einer Tabelle aus Zeitstemplen, die später zu den Messdaten hinzugefügt wird
            timeVec = posixtime(handles.triggerTime + ScanData.Time) * 1000 * msToNs;
            Ttime = table(int64(timeVec), 'VariableNames', {'time'});

            % Konvertiere timetable zu table, Spalte "Time" wurde schon ausgewertet
            ScanData = timetable2table(ScanData, 'ConvertRowTimes', false);
            ScanData.Properties.VariableNames = handles.lastFilteredData.channelnames;

            % Kombiniere Zeit und Spannungsdaten.
            Tcombined = [Ttime, ScanData];

            % Wandle die kombinierte Tabelle in ein Struct-Array um (jede Zeile ein Struct).
            newData = table2struct(Tcombined, 'ToScalar', false);

            % Füge für jedes Struct zusätzliche Felder für Tags hinzu:
            [newData.dataType] = deal("matlabData");
            [newData.measurementName] = deal(handles.lastFilteredData.measurementName); %füge evtl für bessere Performance lieber eine Tabellenspalte vorher hinzu, anstatt deal zu nutzen

            % Hänge die neuen Daten an den Puffer an.
            handles.measurementBuffer = [handles.measurementBuffer; newData(:)];

            % Sende Pakete, solange genügend Elemente im Puffer vorhanden sind.
            while numel(handles.measurementBuffer) >= handles.numPointsThreshold
                packet = handles.measurementBuffer(1:handles.numPointsThreshold);
                handles.measurementBuffer(1:handles.numPointsThreshold) = [];

                jsonStr = jsonencode(packet);
                %disp(jsonStr);
                write(handles.mqttClient, handles.dataTopic, jsonStr,QualityOfService=1);
                %fprintf('Gesendetes Datenpaket: %s\n', jsonStr);
            end
            % Messe die verstrichene Zeit von read bis Ende des aktuellen Schleifendurchlaufs
            actualTime = toc(conversionTime);
            performance = scans / actualTime;  % gesendete Scans pro Sekunde
            disp(['Performance: ' num2str(performance) ' Scans/s']);
        catch ME
            fprintf('Fehler in sendData: %s\n', ME.message);
        end
    end

    function dispLastFiltered()
        fprintf("\n--- Nachricht nach Kürzen und Verrechnung der Einheiten (letzter gültiger Stand) ---\n");
        fprintf("Start/Stop Status: %s\n", handles.lastFilteredData.startStop);
        fprintf("Abtastrate (Hz): %d\n", handles.lastFilteredData.abtastrateHz);
        fprintf("Messungsname: %s\n", handles.lastFilteredData.measurementName);
        fprintf("Channels: %s\n", strjoin(handles.lastFilteredData.channel, ", "));
        fprintf("ChannelNames: %s\n", strjoin(handles.lastFilteredData.channelnames, ", "));
        fprintf("Einheiten: %s\n", strjoin(handles.lastFilteredData.einheit, ", "));
        fprintf("Messrichtungen (noch nicht einberechnet): %s\n", strjoin(handles.lastFilteredData.messrichtung, ", "));
        fprintf("Notizen: %s\n", strjoin(handles.lastFilteredData.notizen, ", "));
        fprintf("MeasuredQuantity: %s\n", strjoin(handles.lastFilteredData.measuredQuantity, ", "));
        fprintf("Sensitivitäten: %s\n", mat2str(handles.lastFilteredData.sensiArray));
        fprintf("Aktuelle Abtastrate: %d Hz\n", handles.d.Rate);
    end
end
