% function response = httpToMqtt(messdauer, abtastrate)

function result = httpToMqtt(ch1, ch2, ch3, ch4, ch5, ch6, ch7, ch8, ch9, ch10, ch11, ch12, ...
    eh1, eh2, eh3, eh4, eh5, eh6, eh7, eh8, eh9, eh10, eh11, eh12, ...
    mr1, mr2, mr3, mr4, mr5, mr6, mr7, mr8, mr9, mr10, mr11, mr12,...
    startStop, sensiArray, abtastrateHz)
    % Diese Funktion nimmt 37 Strings, ein Zahlenarray und eine einzelne Zahl als Eingabe
    % und gibt einen kombinierten String zurück
    %
    % Eingabe:
    %   ch1 - ch12 - Einzelne channels -string
    %   eh1 - eh12  - Einheiten -string
    %   mr1 - mr12  - Messrichtungen - string
    %   startStop   - string
    %   sensiArray  - Array von Sensitivity - double
    %   nabtastrateHz       - Abtastrate  - double 
  
    % Diese Funktion verpackt die Eingabedaten in ein JSON-Format
    % und sendet die Nachricht über MQTT

    % MQTT-Broker-Adresse und Topic
    mqttClient = mqttclient("tcp://host.docker.internal:1884");
    topic = "test/control"; % MQTT-Topic anpassen

    % JSON-Struktur erstellen
    jsonData = struct( ...
    'channel', { {ch1, ch2, ch3, ch4, ch5, ch6, ch7, ch8, ch9, ch10, ch11, ch12} }, ...
    'einheit', { {eh1, eh2, eh3, eh4, eh5, eh6, eh7, eh8, eh9, eh10, eh11, eh12} }, ...
    'messrichtung', { {mr1, mr2, mr3, mr4, mr5, mr6, mr7, mr8, mr9, mr10, mr11, mr12} }, ...
    'sensiArray', sensiArray, ...
    'startStop', startStop, ...
    'abtastrateHz', abtastrateHz ...
);

    % JSON konvertieren
    jsonMessage = jsonencode(jsonData);

    write(mqttClient, topic, jsonMessage);

    % Erfolgreiche Verarbeitung zurückgeben
    result = "JSON gesendet: " + jsonMessage;
end



    % % Debugging: Eingehende Werte anzeigen
    % disp("Eingehende Werte:");
    % disp("Messdauer: " + string(messdauer));
    % disp("Abtastrate: " + string(abtastrate));

    % % MQTT-Broker-Adresse und Topic
    % mqttClient = mqttclient("tcp://host.docker.internal:1884");
    % topic = "test/control"; % MQTT-Topic anpassen

    % try
    %     % JSON-Paket für MQTT erstellen
    %     mqttPayload = struct('messdauer', messdauer, 'abtastrate', abtastrate);
    %     mqttMessage = jsonencode(mqttPayload);

    %     % Nachricht an MQTT senden
    %     write(mqttClient, topic, mqttMessage);
    %     disp("✅ Nachricht an MQTT gesendet: " + mqttMessage);

        % % Erfolgsmeldung zurückgeben
        % response = ["Nachricht gesendet:", mqttMessage];

    % catch ME
    %     disp("❌ Fehler beim Verarbeiten der Anfrage: " + ME.message);
    %     response = ["Fehler beim Verarbeiten der Anfrage:", ME.message];
    % end
% end