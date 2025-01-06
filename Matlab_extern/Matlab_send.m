% MQTT Client für MATLAB erstellen und konfigurieren
mqttClient = mqttclient("tcp://localhost:1884");

% Topic definieren
topic = 'test/topic';

% Parameter für das Sinussignal
desiredFrequency = 1000; % Gewünschte Schleifenfrequenz in Hz
dt = 1 / desiredFrequency; % Zeit zwischen zwei Iterationen
samplingRate = 1000; % Abtastrate des Timers (für kontinuierliches Signal)
signalFrequency1 = 0.5; % Frequenz für Sensor1 in Hz
signalFrequency2 = 0.3; % Frequenz für Sensor2 in Hz
amplitude1 = 1; % Amplitude für Sensor1
amplitude2 = 2; % Amplitude für Sensor2

% Geschlossene Funktion (Closure) für das Signal-Update erstellen
signalUpdater = createSignalUpdater(amplitude1, signalFrequency1, amplitude2, signalFrequency2, 1 / samplingRate);

% Start der Signal- und MQTT-Datenübertragung
disp('Start der Signal- und MQTT-Datenübertragung...');
try
    % Timer für das Sinussignal
    signalTimer = timer(...
        'ExecutionMode', 'fixedRate', ...
        'Period', 1 / samplingRate, ...
        'TimerFcn', @(~,~) signalUpdater(true));

    % Timer starten
    start(signalTimer);

    % Zeitmessung für Schleifenbegrenzung
    totalTime = 0; % Gesamtzeit für alle Iterationen
    iterations = 8000; % Anzahl der Iterationen

    % Startzeit der ersten Iteration
    lastIterationStart = tic;

    % Endlosschleife für das Senden der Daten
    for i = 1:iterations
        % Aktuelle Startzeit der Iteration
        iterationStart = tic;

        % Einfache Daten generieren (Zeitstempel hinzufügen)
        timeStamp = posixtime(datetime('now')); % Unix-Zeitstempel

        % Aktuelle Sensorwerte abrufen
        [sensor1Value, sensor2Value] = signalUpdater();

        % Sensor1-Daten
        sensor1Data = struct('time', timeStamp, ...
                             'Sensor1', sensor1Value, ...
                             'location', 'Room1', ...
                             'device', 'DeviceA');

        % Sensor2-Daten
        sensor2Data = struct('time', timeStamp, ...
                             'Sensor2', sensor2Value, ...
                             'location', 'Room2', ...
                             'device', 'DeviceB');

        % JSON-Daten für Sensor1 senden
        payload1 = jsonencode(sensor1Data);
        write(mqttClient, topic, payload1);

        % JSON-Daten für Sensor2 senden
        payload2 = jsonencode(sensor2Data);
        write(mqttClient, topic, payload2);

        % Wartezeit berechnen und pausieren
        elapsedIterationTime = toc(iterationStart); % Zeit für die Iteration
        remainingTime = dt - elapsedIterationTime; % Verbleibende Zeit
        if remainingTime > 0
            pause(remainingTime); % Warten, um die gewünschte Frequenz zu halten
        end

        % Gesamtzeit aktualisieren
        totalTime = totalTime + toc(lastIterationStart);
        lastIterationStart = tic;

        % Fortschritt anzeigen
        if mod(i, 100) == 0
            disp(['Iteration ' num2str(i) ' abgeschlossen. Durchschnittszeit pro Iteration: ' num2str(totalTime / i) ' Sekunden']);
        end
    end

    % Durchschnittszeit und Abtastrate berechnen
    averageTime = totalTime / iterations;
    actualFrequency = 1 / averageTime; % Tatsächliche Schleifenfrequenz
    disp(['Durchschnittliche Zeit pro Iteration: ' num2str(averageTime) ' Sekunden']);
    disp(['Tatsächliche Abtastrate: ' num2str(actualFrequency) ' Hz']);

    % Timer stoppen
    stop(signalTimer);
    delete(signalTimer);

catch ME
    disp('Skript wurde gestoppt.');
    disp(['Fehler: ' ME.message']);
end

disp('Signalübertragung abgeschlossen.');

% Funktion zum Erstellen des Signal-Updaters
function updater = createSignalUpdater(amplitude1, freq1, amplitude2, freq2, dt)
    % Geschlossene Variablen
    t = 0; % Startzeit
    sensor1Value = 0;
    sensor2Value = 0;

    % Aktualisierungsfunktion
    updater = @updateSignal;

    function [s1, s2] = updateSignal(incrementTime)
        if nargin > 0 && incrementTime
            % Zeitvariable nur aktualisieren, wenn explizit angefordert
            t = t + dt;
        end

        % Sinus-Signale generieren
        sensor1Value = amplitude1 * sin(2 * pi * freq1 * t);
        sensor2Value = amplitude2 * sin(2 * pi * freq2 * t);

        % Rückgabe der aktuellen Sensorwerte
        s1 = sensor1Value;
        s2 = sensor2Value;
    end
end