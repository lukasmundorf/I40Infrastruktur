function response = httpToMqtt(messdauer, abtastrate)
    % Debugging: Eingehende Werte anzeigen
    disp("Eingehende Werte:");
    disp("Messdauer: " + string(messdauer));
    disp("Abtastrate: " + string(abtastrate));

    % MQTT-Broker-Adresse und Topic
    mqttClient = mqttclient("tcp://host.docker.internal:1884");
    topic = "test/control"; % MQTT-Topic anpassen

    try
        % JSON-Paket für MQTT erstellen
        mqttPayload = struct('messdauer', messdauer, 'abtastrate', abtastrate);
        mqttMessage = jsonencode(mqttPayload);

        % Nachricht an MQTT senden
        write(mqttClient, topic, mqttMessage);
        disp("✅ Nachricht an MQTT gesendet: " + mqttMessage);

        % Erfolgsmeldung zurückgeben
        response = ["Nachricht gesendet:", mqttMessage];

    catch ME
        disp("❌ Fehler beim Verarbeiten der Anfrage: " + ME.message);
        response = ["Fehler beim Verarbeiten der Anfrage:", ME.message];
    end
end