function receive
    %% Hauptskript
    clc;
    daqreset;  % Setzt das gesamte DAQ-Subsystem zurück
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
    handles.topic = "test/control";    % Für Steuerbefehle
    handles.dataTopic = "test/topic";    % Für das Senden von Daten

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
                disp(datetime("now"));
                data = jsondecode(payload);
                
                fprintf("\n--- Originale Nachricht ---\n");
                fprintf("Start/Stop Status: %s\n", data.startStop);
                fprintf("Abtastrate (Hz): %d\n", data.abtastrateHz);
                fprintf("Messungsname: %s\n", data.measurementName);
                fprintf("Channels: %s\n", strjoin(data.channel, ", "));
                fprintf("Einheiten: %s\n", strjoin(data.einheit, ", "));
                fprintf("Messrichtungen: %s\n", strjoin(data.messrichtung, ", "));
                fprintf("Notizen: %s\n", strjoin(data.notizen, ", "));
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
                    % Filtere die Channels:
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
                    channelNumbers = sort(channelNumbers);
                    activeIdx = channelNumbers + 1;
                    
                    data.einheit      = data.einheit(activeIdx);
                    data.messrichtung = data.messrichtung(activeIdx);
                    data.notizen      = data.notizen(activeIdx);
                    data.sensiArray   = data.sensiArray(activeIdx);
                    data.channel = arrayfun(@(x) num2str(x), channelNumbers, 'UniformOutput', false);
                    
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
                    
                    fprintf("\n--- Nachricht nach Kürzen ---\n");
                    fprintf("Start/Stop Status: %s\n", data.startStop);
                    fprintf("Abtastrate (Hz): %d\n", data.abtastrateHz);
                    fprintf("Messungsname: %s\n", data.measurementName);
                    fprintf("Channels: %s\n", strjoin(data.channel, ", "));
                    fprintf("Einheiten: %s\n", strjoin(data.einheit, ", "));
                    fprintf("Messrichtungen: %s\n", strjoin(data.messrichtung, ", "));
                    fprintf("Notizen: %s\n", strjoin(data.notizen, ", "));
                    fprintf("Sensitivitäten: %s\n", mat2str(data.sensiArray));
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
        t = posixtime(datetime('now', 'TimeZone', 'local'));
        t_ms = round(t * 1000 * msToNs);
        
        % Für jeden Channel:
        for idx = 1:length(metadata.channel)
            data_struct = struct(...
                'ChannelName', sprintf('ch%s', metadata.channel{idx}), ...
                'time', t_ms + idx, ...  % Leicht erhöhter Zeitstempel
                'sensitivity', num2str(metadata.sensiArray(idx)), ...
                'messrichtung', metadata.messrichtung{idx}, ...
                'notizen', metadata.notizen{idx}, ...
                'einheit', metadata.einheit{idx}, ...
                'dataType', 'metadata', ...
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
            [ScanData, triggerTime] = handles.d.read("all", "OutputFormat", "Timetable");
            if ~isempty(ScanData)
                % Verarbeitung analog zur sendData()-Funktion:
                timeVec = posixtime(triggerTime + ScanData.Time) * 1000 *msToNs - 3600*1000*msToNs;
                Ttime = table(int64(timeVec), 'VariableNames', {'time'});
                voltageData = table2array(ScanData);
                nChannels = size(voltageData, 2);

                % Verwende die aktiven Kanäle aus lastFilteredData für die Spaltennamen:
                activeChannels = handles.lastFilteredData.channel;
                varNames = cellfun(@(ch) sprintf('voltage%s', ch), activeChannels, 'UniformOutput', false);
                Tvolt = array2table(voltageData, 'VariableNames', varNames);
                Tcombined = [Ttime, Tvolt];

                newData = table2struct(Tcombined, 'ToScalar', false);
                [newData.dataType] = deal("data");
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
            disp(datetime("now"));
            scans = handles.d.NumScansAvailable;

            conversionTime = tic;  % Start der Zeitmessung (read bis write)
            [ScanData, triggerTime] = handles.d.read("all", "OutputFormat", "Timetable");
            disp("Nach read: ");
            disp([handles.d.NumScansAvailable, handles.d.NumScansAcquired]);

            % Umrechnung des Trigger-Zeitpunkts in Unixzeit (ns) – Rundungsfehler hier vernachlässigbar:
            trigger_ns = int64(posixtime(triggerTime) * 1e9);

            % Umrechnung des Offsets aus ScanData.Time (als duration) in Sekunden und dann in Nanosekunden:
            offset_sec = seconds(ScanData.Time);
            offset_ns = int64(round(offset_sec * 1e9 - 3600 * 1e9));

            % Gesamter Zeitstempel: Trigger-Zeit plus Offset.
            timeVec = trigger_ns + offset_ns;
            % Erzwinge einen Spaltenvektor, um konsistente Tabellen zu erhalten:
            timeVec = timeVec(:);
            Ttime = table(timeVec, 'VariableNames', {'time'});

            % Extrahiere die Spannungsdaten und wandle sie in eine Tabelle um.
            voltageData = table2array(ScanData);
            % Verwende die aktiv gefilterten Kanalnummern aus lastFilteredData für die Feldnamen.
            activeChannels = handles.lastFilteredData.channel;  % z. B. {"0", "2", "4", "8", "10"}
            varNames = cellfun(@(ch) sprintf('voltage%s', ch), activeChannels, 'UniformOutput', false);
            Tvolt = array2table(voltageData, 'VariableNames', varNames);

            % Kombiniere Zeit und Spannungsdaten.
            Tcombined = [Ttime, Tvolt];

            % Wandle die kombinierte Tabelle in ein Struct-Array um (jede Zeile ein Struct).
            newData = table2struct(Tcombined, 'ToScalar', false);

            % Füge für jedes Struct zusätzliche Felder hinzu:
            [newData.dataType] = deal("data");
            [newData.measurementName] = deal(handles.lastFilteredData.measurementName);

            % Hänge die neuen Daten an den Puffer an.
            handles.measurementBuffer = [handles.measurementBuffer; newData(:)];

            % Sende Pakete, solange genügend Elemente im Puffer vorhanden sind.
            while numel(handles.measurementBuffer) >= handles.numPointsThreshold
                packet = handles.measurementBuffer(1:handles.numPointsThreshold);
                handles.measurementBuffer(1:handles.numPointsThreshold) = [];

                jsonStr = jsonencode(packet);
                disp(jsonStr);
                write(handles.mqttClient, handles.dataTopic, jsonStr);
            end

            % Messe die verstrichene Zeit von read bis Ende des aktuellen Schleifendurchlaufs.
            actualTime = toc(conversionTime);
            performance = scans / actualTime;  % gesendete Scans pro Sekunde.
            disp(['Performance: ' num2str(performance) ' Scans/s']);
        catch ME
            fprintf('Fehler in sendData: %s\n', ME.message);
        end
    end


    function dispLastFiltered()
        fprintf("\n--- Nachricht nach Kürzen (letzter gültiger Stand) ---\n");
        fprintf("Start/Stop Status: %s\n", handles.lastFilteredData.startStop);
        fprintf("Abtastrate (Hz): %d\n", handles.lastFilteredData.abtastrateHz);
        fprintf("Messungsname: %s\n", handles.lastFilteredData.measurementName);
        fprintf("Channels: %s\n", strjoin(handles.lastFilteredData.channel, ", "));
        fprintf("Einheiten: %s\n", strjoin(handles.lastFilteredData.einheit, ", "));
        fprintf("Messrichtungen: %s\n", strjoin(handles.lastFilteredData.messrichtung, ", "));
        fprintf("Notizen: %s\n", strjoin(handles.lastFilteredData.notizen, ", "));
        fprintf("Sensitivitäten: %s\n", mat2str(handles.lastFilteredData.sensiArray));
        fprintf("Aktuelle Abtastrate: %d Hz\n", handles.d.Rate);
    end
end
