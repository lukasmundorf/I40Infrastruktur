% Erstelle das Data Acquisition Objekt (neues Objekt, nicht session)
d = daq('dt');
% Hier können bei Bedarf erste Eingänge konfiguriert werden, falls nötig:
% d.addinput("DT9836(00)", 0, "Voltage");

% MQTT-Broker-Adresse und Topic
mqttClient = mqttclient("tcp://localhost:1884");

% Verbindung prüfen
disp("Verbindung hergestellt: " + string(mqttClient.Connected));

% Abonniere das gewünschte Topic
topic = "test/control";
subscribe(mqttClient, topic);
disp("Abonniert auf das Topic: " + topic);

% Variable zur Steuerung des Messstatus (false = nicht messen, true = messen)
isMeasuring = false;
% Variable, in der der zuletzt gültig verarbeitete, gefilterte Zustand gespeichert wird
lastFilteredData = [];

% Endlosschleife zum Empfangen und Verarbeiten von Nachrichten
while true
    % Verfügbare Nachrichten vom abonnierten Topic lesen mit Timeout von 5 Sekunden
    messages = read(mqttClient, Topic=topic);
    
    % Wenn Nachrichten vorhanden sind, diese verarbeiten
    if ~isempty(messages)
        for i = 1:height(messages)
            % JSON-Payload aus der Nachricht extrahieren
            payload = string(messages.Data(i));
            
            try
                fprintf("Anzahl der Nachrichten: %d\n", height(messages));
                % JSON-Daten decodieren
                data = jsondecode(payload);

                % Ausgabe der Originaldaten
                disp(datetime("now"));
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
                if strcmpi(data.startStop, "start") && isMeasuring
                    fprintf("\nMessung läuft bereits, 'start' wird ignoriert.\n");
                    if ~isempty(lastFilteredData)
                        fprintf("\n--- Nachricht nach Kürzen (letzter gültiger Stand) ---\n");
                        fprintf("Start/Stop Status: %s\n", lastFilteredData.startStop);
                        fprintf("Abtastrate (Hz): %d\n", lastFilteredData.abtastrateHz);
                        fprintf("Messungsname: %s\n", lastFilteredData.measurementName);
                        fprintf("Channels: %s\n", strjoin(lastFilteredData.channel, ", "));
                        fprintf("Einheiten: %s\n", strjoin(lastFilteredData.einheit, ", "));
                        fprintf("Messrichtungen: %s\n", strjoin(lastFilteredData.messrichtung, ", "));
                        fprintf("Notizen: %s\n", strjoin(lastFilteredData.notizen, ", "));
                        fprintf("Sensitivitäten: %s\n", mat2str(lastFilteredData.sensiArray));
                        fprintf("Aktuelle Abtastrate: %d Hz\n", d.Rate);
                    end
                    continue; % Überspringe diese Nachricht
                elseif strcmpi(data.startStop, "stop") && ~isMeasuring
                    fprintf("\nMessung ist bereits gestoppt, 'stop' wird ignoriert.\n");
                    if ~isempty(lastFilteredData)
                        fprintf("\n--- Nachricht nach Kürzen (letzter gültiger Stand) ---\n");
                        fprintf("Start/Stop Status: %s\n", lastFilteredData.startStop);
                        fprintf("Abtastrate (Hz): %d\n", lastFilteredData.abtastrateHz);
                        fprintf("Messungsname: %s\n", lastFilteredData.measurementName);
                        fprintf("Channels: %s\n", strjoin(lastFilteredData.channel, ", "));
                        fprintf("Einheiten: %s\n", strjoin(lastFilteredData.einheit, ", "));
                        fprintf("Messrichtungen: %s\n", strjoin(lastFilteredData.messrichtung, ", "));
                        fprintf("Notizen: %s\n", strjoin(lastFilteredData.notizen, ", "));
                        fprintf("Sensitivitäten: %s\n", mat2str(lastFilteredData.sensiArray));
                        fprintf("Aktuelle Abtastrate: %d Hz\n", d.Rate);
                    end
                    continue; % Überspringe die Aktualisierung der Arrays
                end
                
                % Falls "start" empfangen wird, wird der Zustand neu gefiltert und gespeichert.
                if strcmpi(data.startStop, "start")
                    % Verarbeite den Channel-Array: extrahiere die Zahlen und sortiere diese
                    channels = data.channel;
                    channelNumbers = [];
                    for k = 1:length(channels)
                        if ~isempty(channels{k})
                            % Entferne den Präfix "ch" und wandle den Rest in eine Zahl um
                            numStr = regexprep(channels{k}, '^ch', '');
                            numVal = str2double(numStr);
                            if ~isnan(numVal)
                                channelNumbers(end+1) = numVal;
                            end
                        end
                    end

                    % Sortiere den Zahlen-Array
                    channelNumbers = sort(channelNumbers);

                    % Bestimme die zu behaltenden Indizes in den anderen Arrays.
                    % Da die Kanalnummern 0-basiert sind, entspricht Index = Kanalnummer + 1.
                    activeIdx = channelNumbers + 1;

                    % Filtere die Arrays "einheit", "messrichtung", "notizen" und "sensiArray"
                    data.einheit      = data.einheit(activeIdx);
                    data.messrichtung = data.messrichtung(activeIdx);
                    data.notizen      = data.notizen(activeIdx);
                    data.sensiArray   = data.sensiArray(activeIdx);

                    % Überschreibe das Feld 'channel' mit den sortierten Zahlen (als Strings)
                    data.channel = arrayfun(@(x) num2str(x), channelNumbers, 'UniformOutput', false);

                    % Aktualisiere im DAQ-Objekt die aktiven Kanäle:
                    % Entferne zunächst alle vorhandenen Eingänge.
                    while ~isempty(d.Channels)
                        d.removechannel(1);
                    end
                    % Füge für jeden aktiven Kanal einen neuen Eingang hinzu.
                    for ch = channelNumbers
                        d.addinput("DT9836(00)", ch, "Voltage");
                    end
                    disp("Aktuell konfigurierte Channels im DAQ-Objekt:");
                    disp(d.Channels);

                    % Abtastrate am DAQ-Objekt anpassen und in den Daten speichern
                    d.Rate = data.abtastrateHz;
                    
                    % Speichere den gefilterten Zustand als letzten gültigen Stand, inklusive Abtastrate
                    lastFilteredData = data;
                    
                    % Ausgabe der gefilterten Daten (nur aktive Channels) inklusive aktueller Abtastrate
                    fprintf("\n--- Nachricht nach Kürzen ---\n");
                    fprintf("Start/Stop Status: %s\n", data.startStop);
                    fprintf("Abtastrate (Hz): %d\n", data.abtastrateHz);
                    fprintf("Messungsname: %s\n", data.measurementName);
                    fprintf("Channels: %s\n", strjoin(data.channel, ", "));
                    fprintf("Einheiten: %s\n", strjoin(data.einheit, ", "));
                    fprintf("Messrichtungen: %s\n", strjoin(data.messrichtung, ", "));
                    fprintf("Notizen: %s\n", strjoin(data.notizen, ", "));
                    fprintf("Sensitivitäten: %s\n", mat2str(data.sensiArray));
                    fprintf("Aktuelle Abtastrate: %d Hz\n", d.Rate);
                end
                
                % Steuerung der Messung anhand des Feldes startStop
                if strcmpi(data.startStop, "start")
                    isMeasuring = true;
                    fprintf("\nMessung wird gestartet...\n");
                    % Hier kann der Start der eigentlichen Messung implementiert werden.
                elseif strcmpi(data.startStop, "stop")
                    isMeasuring = false;
                    fprintf("\nMessung wird gestoppt...\n");
                    % Hier kann der Stopp der Messung implementiert werden.
                else
                    fprintf("\nUnbekannter Start/Stop Befehl: %s\n", data.startStop);
                end
                                
            catch ME
                % Falls Decodierung fehlschlägt, Payload direkt ausgeben
                fprintf("[%s] %s: Fehler beim Verarbeiten des Payloads: %s\n", ...
                    datestr(messages.Time(i), 'HH:MM:SS'), ...
                    messages.Topic(i), ...
                    payload);
            end
        end
    end

    % Kurze Pause, um die CPU-Auslastung zu reduzieren
    pause(0.5);
end
