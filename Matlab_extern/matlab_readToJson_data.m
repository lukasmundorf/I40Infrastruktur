clearvars;
daqreset;

% Parameter: Paketgröße (Anzahl der Scans pro gesendetem Paket)
packageSize = 1000;  % Ändere diesen Wert nach Bedarf

% MQTT-Client erstellen und konfigurieren
mqttClient = mqttclient("tcp://localhost:1884");
assert(mqttClient.Connected, 'MQTT Client ist nicht verbunden!');
pause(0.01);

topic = 'test/topic';

% DAQ-Objekt erstellen und konfigurieren
a = daq('dt');
a.Rate = 10000;

% 12 Eingänge hinzufügen (Kanalnummern 0 bis 11)
for ch = 0:11
    a.addinput("DT9836(00)", ch, "Voltage");
end

disp(a.Channels);

% Acquisition im kontinuierlichen Modus starten
start(a, "continuous");

% Buffer für gesammelte Daten initialisieren
bufferStruct = [];

while true
    pause(0.2); 
    
    % Ausgabe des Bufferstatus vor dem Lesen:
    disp("Vor read: ");
    disp([a.NumScansAvailable, a.NumScansAcquired]);
    disp(datetime("now"));
    scans = a.NumScansAvailable;
    
    conversionTime = tic;  % Start der Zeitmessung (read bis write)
    
    % Lese alle verfügbaren Scans als Timetable und erhalte triggerTime
    [ScanData, triggerTime] = a.read("all", "OutputFormat", "Timetable");
    
    disp("Nach read: ");
    disp([a.NumScansAvailable, a.NumScansAcquired]);
    
    % Berechne den Unix-Zeitstempel (in Millisekunden) vektorisert 
    % und korrigiere um 3600 Sekunden (1 Stunde) zurück:
    timeVec = posixtime(triggerTime + ScanData.Time) * 1000 - 3600 * 1000;
    
    % Erstelle eine Tabelle mit der Zeitspalte
    Ttime = table(int64(timeVec), 'VariableNames', {'time'});
    
    % Extrahiere die Spannungsdaten und wandle sie in eine Tabelle um
    voltageData = table2array(ScanData);
    nChannels = size(voltageData, 2);
    varNames = arrayfun(@(j) sprintf('voltage%d', j-1), 1:nChannels, 'UniformOutput', false);
    Tvolt = array2table(voltageData, 'VariableNames', varNames);
    
    % Kombiniere Zeit und Spannungsdaten (Zeitspalte zuerst)
    Tcombined = [Ttime, Tvolt];
    
    % Umwandlung der kombinierten Tabelle in ein Struct-Array (jede Zeile ein Struct)
    newData = table2struct(Tcombined, 'ToScalar', false);
    
    % Füge für jedes Struct das zusätzliche Feld "dataType" mit Wert "data" hinzu
    [newData.dataType] = deal("data");
    
    % Füge für jedes Struct das zusätzliche Feld "measurementName" mit Wert "abc" hinzu
    [newData.measurementName] = deal("abc");
    
    % Füge die neuen Daten dem Buffer hinzu
    bufferStruct = [bufferStruct; newData(:)];
    
    % Sende Pakete, solange mindestens "packageSize" Elemente im Buffer vorhanden sind
    while numel(bufferStruct) >= packageSize
        packet = bufferStruct(1:packageSize);  % Nehme die ersten "packageSize" Elemente
        bufferStruct(1:packageSize) = [];      % Entferne diese aus dem Buffer
        
        % Umwandlung in JSON und Senden via MQTT
        jsonStr = jsonencode(packet);
        write(mqttClient, topic, jsonStr);
    end
    
    % Messe die verstrichene Zeit von read bis Ende des aktuellen Schleifendurchlaufs
    actualTime = toc(conversionTime);
    performance = scans / actualTime;  % gesendete Scans pro Sekunde
    disp(['Performance: ' num2str(performance) ' Scans/s']);
end
