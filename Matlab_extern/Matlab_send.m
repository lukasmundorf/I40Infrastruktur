

% MQTT Client für MATLAB erstellen und konfigurieren
%mqttClient = mqttclient("tcp://localhost",ClientID="",Port=1884)
mqttClient = mqttclient("tcp://localhost:1884");

% Topic definieren
topic = 'test/topic';

% Endlosschleife für den kontinuierlichen Versand
disp('Start des kontinuierlichen MQTT-Datenversands...');
try
    i = 1; % Initialisierung des Zählers
    while i<21
        % Einfache Daten generieren
        timeStamp = posixtime(datetime('now')); % Unix-Zeitstempel
        sampleValue = i; % Beispiel-Daten: hochzählender Zähler

        % Daten in Struktur speichern
        output = struct('time', timeStamp, 'value', sampleValue);

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

