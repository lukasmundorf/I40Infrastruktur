function response = httpToMqtt(request)
    % HTTP-Anfrage verarbeiten und an MQTT-Broker senden

    % MQTT-Broker-Adresse und Topic
    mqttClient = mqttclient("tcp://host.docker.internal:1884");



     topic = "test/control"; % Passen Sie das gewünschte Topic an


    % Daten als MQTT-Nachricht senden
    write(mqttClient, topic, num2str(request));

    % Antwort erstellen
    response = ["Nachricht gesendet: " request];  

end