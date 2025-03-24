% Funktion httpToMqtt: Verpackt verschiedene Messparameter in eine JSON-Struktur 
% und versendet diese als MQTT-Nachricht.
%
% Eingabeparameter:
%   ch1 - ch12          : Strings, die einzelne Kanalbezeichnungen enthalten
%   eh1 - eh12          : Strings, die die zugehörigen Einheiten der Kanäle beschreiben
%   mr1 - mr12          : Strings, die die Messrichtungen angeben
%   no1 - no12          : Strings für Notizen zu den jeweiligen Kanälen
%   mQ0 - mQ11          : Strings, die die gemessenen Größen definieren
%   startStop         : String, der den Start- oder Stop-Befehl angibt
%   sensiArray        : Double-Array, das die Sensitivitätswerte enthält
%   abtastrateHz      : Double, die Abtastrate in Hertz
%   measurementName   : String, der den Namen der Messung beschreibt
%
% Ablauf:
% 1. Aufbau der Verbindung zum MQTT-Broker.
% 2. Zusammenstellung der Eingabedaten in eine strukturierte JSON-Formatierung.
% 3. Kodierung der Daten als JSON-String.
% 4. Versand der JSON-Nachricht an das definierte MQTT-Topic.
% 5. Rückgabe einer Bestätigungsmeldung, dass die JSON-Nachricht gesendet wurde.

function result = httpToMqtt(ch1, ch2, ch3, ch4, ch5, ch6, ch7, ch8, ch9, ch10, ch11, ch12, ...
    eh1, eh2, eh3, eh4, eh5, eh6, eh7, eh8, eh9, eh10, eh11, eh12, ...
    mr1, mr2, mr3, mr4, mr5, mr6, mr7, mr8, mr9, mr10, mr11, mr12, ...
    no1, no2, no3, no4, no5, no6, no7, no8, no9, no10, no11, no12, ...
    mQ0, mQ1, mQ2, mQ3, mQ4, mQ5, mQ6, mQ7, mQ8, mQ9, mQ10, mQ11, ...
    startStop, sensiArray, abtastrateHz, measurementName)

    % Aufbau der MQTT-Verbindung zum Broker
    % Hinweis: Passen Sie die Broker-Adresse und den Port ggf. an Ihre Umgebung an
    mqttClient = mqttclient("tcp://host.docker.internal:1884");
    
    % Definition des MQTT-Topics, unter dem die Nachricht veröffentlicht wird
    topic = "control/measurement"; 

    % Erstellen einer Struktur, die alle Eingabedaten zur Messung enthält.
    % Dabei werden die einzelnen Strings in Zellenarrays zusammengefasst.
    jsonData = struct( ...
        'channel', { {ch1, ch2, ch3, ch4, ch5, ch6, ch7, ch8, ch9, ch10, ch11, ch12} }, ...
        'einheit', { {eh1, eh2, eh3, eh4, eh5, eh6, eh7, eh8, eh9, eh10, eh11, eh12} }, ...
        'messrichtung', { {mr1, mr2, mr3, mr4, mr5, mr6, mr7, mr8, mr9, mr10, mr11, mr12} }, ...
        'notizen', { {no1, no2, no3, no4, no5, no6, no7, no8, no9, no10, no11, no12} }, ...
        'measuredQuantity', { {mQ0, mQ1, mQ2, mQ3, mQ4, mQ5, mQ6, mQ7, mQ8, mQ9, mQ10, mQ11} }, ...
        'sensiArray', sensiArray, ...
        'startStop', startStop, ...
        'abtastrateHz', abtastrateHz, ...
        'measurementName', measurementName ...
    );

    % Umwandlung der Struktur in einen JSON-String
    jsonMessage = jsonencode(jsonData);

    % Senden des JSON-Strings an das angegebene MQTT-Topic
    write(mqttClient, topic, jsonMessage);

    % Rückgabe einer Bestätigungsmeldung
    result = "JSON gesendet: " + jsonMessage;
end
