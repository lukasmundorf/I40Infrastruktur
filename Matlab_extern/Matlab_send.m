

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