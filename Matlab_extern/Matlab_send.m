%{
% Konfiguriere den MQTT-Broker
%brokerAddress = "tcp://localhost:1884"; % Mosquitto-Broker-Adresse und Port
%mqttClient = mqttclient(brokerAddress);
mqttClient = mqttclient("tcp://localhost",ClientID="",Port=1884)

% Überprüfe die Verbindung
if mqttClient.Connected
    disp("Erfolgreich mit Mosquitto verbunden.");
else
    disp("Verbindung fehlgeschlagen. Überprüfe Mosquitto.");
    return;
end

% Definiere das Topic und die Nachricht
topic = "testtopic"; % Das Topic, auf dem die Nachricht veröffentlicht wird
message = "4";      % Die Nachricht, die gesendet wird

% Veröffentliche die Nachricht
try
    disp("MQTT Client:"); disp(mqttClient);
    disp("Topic:"); disp(topic);
    disp("Message:"); disp(message);
    disp("Ist Topic ein String?");
    disp(isstring(topic)); % Sollte '1' zurückgeben
    publish(mqttClient, topic, message);
    disp("Nachricht gesendet: " + message + " an Topic: " + topic);
catch ME
    disp("Fehler beim Veröffentlichen der Nachricht:");
    disp(ME.message);
end

% Schließe die Verbindung
clear mqttClient;0

%}

% MQTT Client für MATLAB erstellen und konfigurieren
%mqttClient = mqttclient("tcp://localhost",ClientID="",Port=1884)
mqttClient = mqttclient("tcp://localhost:1884");

% Nachricht (Zahl 8) definieren
message = '299';

% Topic definieren
topic = 'test/topic';

% Nachricht veröffentlichen
write(mqttClient, topic, message);



% Client löschen
clear mqttClient;

disp('Nachricht "8" wurde erfolgreich an den MQTT-Broker gesendet.');
