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

        % Daten in Struktur speichern (zwei Sensorwerte + Zeit)
        output = struct('time', timeStamp, ...
                        'Sensor1', sensor1Value, ...
                        'Sensor2', sensor2Value);

        % Daten in JSON konvertieren
        payload = jsonencode(output);

        % JSON-Daten an den Broker senden
        write(mqttClient, topic, payload);
        disp(['Daten gesendet: ' payload]);

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