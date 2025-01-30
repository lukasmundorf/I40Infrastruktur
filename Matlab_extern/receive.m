 % MQTT-Broker-Adresse und Topic
 mqttClient = mqttclient("tcp://localhost:1884");

 mqttClient.Connected

 topic = "test/control";
 
 subscribe(mqttClient, topic)
 disp("Abonniert auf das Topic: " + topic);

 % Endlosschleife zum Empfangen und Ausgeben von Nachrichten
while true
    % Verfügbare Nachrichten vom abonnierten Topic lesen mit Timeout von 5 Sekunden
    messages = read(mqttClient, Topic=topic);
    
    % Wenn Nachrichten vorhanden sind, diese ausgeben
    if ~isempty(messages)
        for i = 1:height(messages)
            fprintf("[%s] %s: %s\n", ...
                datestr(messages.Time(i), 'HH:MM:SS'), ...
                messages.Topic(i), ...
                string(messages.Data(i)));
        end
    end
    
    % Kurze Pause, um die CPU-Auslastung zu reduzieren
    pause(0.5);
end