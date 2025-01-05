% MQTT Client für MATLAB erstellen und konfigurieren
mqttClient = mqttclient("tcp://localhost:1884");

% Topic definieren
topic = 'test/topic';

% Endlosschleife für den kontinuierlichen Versand
disp('Start des kontinuierlichen MQTT-Datenversands...');
try
    i = 1; % Initialisierung des Zählers
    while i < 21
        % Einfache Daten für zwei Sensoren generieren
        timeStamp = posixtime(datetime('now')); % Unix-Zeitstempel
        sensor1Value = i * 1.1; % Beispiel-Daten für Sensor1
        sensor2Value = i * 2.2; % Beispiel-Daten für Sensor2

         % Sensor1-Daten
        sensor1Data = struct('time', timeStamp, ...
                             'Sensor1', sensor1Value, ...
                             'location', 'Room1', ...
                             'device', 'DeviceA');
        
        % Sensor2-Daten
        sensor2Data = struct('time', timeStamp, ...
                             'Sensor2', sensor2Value, ...
                             'location', 'Room2', ...
                             'device', 'DeviceB');

        % JSON-Daten für Sensor1 senden
        payload1 = jsonencode(sensor1Data);
        write(mqttClient, topic, payload1);
        disp(['Daten für Sensor1 gesendet: ' payload1]);

        % JSON-Daten für Sensor2 senden
        payload2 = jsonencode(sensor2Data);
        write(mqttClient, topic, payload2);
        disp(['Daten für Sensor2 gesendet: ' payload2]);

        % Pause für 1 Sekunde
        pause(1);

        % Zähler erhöhen
        i = i + 1;
    end
catch ME
    disp('Skript wurde gestoppt.');
    disp(['Fehler: ' ME.message]);
end

disp('MQTT-Datenversand abgeschlossen.');