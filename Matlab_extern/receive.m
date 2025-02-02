% MQTT-Broker-Adresse und Topic
mqttClient = mqttclient("tcp://localhost:1884");

% Verbindung prüfen
disp("Verbindung hergestellt: " + string(mqttClient.Connected));

% Abonniere das gewünschte Topic
topic = "test/control";
subscribe(mqttClient, topic);
disp("Abonniert auf das Topic: " + topic);

% Endlosschleife zum Empfangen und Verarbeiten von Nachrichten
while true
    % Verfügbare Nachrichten vom abonnierten Topic lesen mit Timeout von 5 Sekunden
    messages = read(mqttClient, Topic=topic);
    
    % Wenn Nachrichten vorhanden sind, diese verarbeiten
    if ~isempty(messages)
        for i = 1:height(messages)
            % JSON-Payload aus der Nachricht extrahieren
            payload = string(messages.Data(i));
            
            try
                % JSON-Daten decodieren
                data = jsondecode(payload);

                % Werte ausgeben
                fprintf("[%s] %s: Messdauer = %d, Abtastrate = %d\n", ...
                    datestr(messages.Time(i), 'HH:MM:SS'), ...
                    messages.Topic(i), ...
                    data.messdauer, ...
                    data.abtastrate);
            catch ME
                % Falls Decodierung fehlschlägt, Payload direkt ausgeben
                fprintf("[%s] %s: Fehler beim Verarbeiten des Payloads: %s\n", ...
                    datestr(messages.Time(i), 'HH:MM:SS'), ...
                    messages.Topic(i), ...
                    payload);
            end
        end
    end

    % Kurze Pause, um die CPU-Auslastung zu reduzieren
    pause(0.5);
end