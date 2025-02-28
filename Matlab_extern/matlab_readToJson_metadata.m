clearvars;
daqreset;
% MQTT Client für MATLAB erstellen und konfigurieren
mqttClient = mqttclient("tcp://localhost:1884");

mqttClient.Connected
pause(1)

% Topic definieren
topic = 'test/topic';

disp('Start der Signal- und MQTT-Datenübertragung...');
% Startzeitpunkt: Aktuelle Unixzeit in Millisekunden (13-stellig)
tStart = posixtime(datetime('now', 'TimeZone', 'local'));
tStart_ms = round(tStart * 1000);
disp(int64(tStart_ms))

% Schleife zum Erstellen und Senden der einzelnen Channel-Daten
for ch = 0:11
    % Erhöhe den Zeitstempel um 1 Millisekunde für jeden Channel
    currentTime = tStart_ms + ch;
    
    % Erstelle die Struktur für den aktuellen Channel mit allen Feldern
    data_struct = struct(...
        'ChannelName', sprintf('ch%d', ch), ...
        'time', currentTime, ...
        'sensitivity', 'hoch', ...
        'messrichtung', 'positiv', ...
        'notizen', 'Beispielnotiz', ...
        'einheit', 'V', ...
        'dataType', 'metadata', ...
        'measurementName', 'abc');
    
    % Konvertiere den Struct in JSON
    json_str = jsonencode(data_struct);
    disp(json_str);
    
    % Sende die JSON-Nachricht über MQTT
    write(mqttClient, topic, json_str);
end

disp("erfolg");
