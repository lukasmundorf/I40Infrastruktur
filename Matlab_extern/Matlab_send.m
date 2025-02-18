clearvars

% MQTT Client für MATLAB erstellen und konfigurieren
mqttClient = mqttclient("tcp://localhost:1884");

mqttClient.Connected

pause(1)

% Topic definieren
topic = 'test/topic';

% Parameter für das Sinussignal
samplingRate = 100; % Abtastrate in Hz
signalFrequency1 = 0.5; % Frequenz für Sensor1 in Hz
signalFrequency2 = 0.3; % Frequenz für Sensor2 in Hz
amplitude1 = 1; % Amplitude für Sensor1
amplitude2 = 2; % Amplitude für Sensor2
dt = 1 / samplingRate; % Abtastintervall

% Geschlossene Funktion (Closure) für das Signal-Update erstellen
signalUpdater = createSignalUpdater(amplitude1, signalFrequency1, amplitude2, signalFrequency2, dt);

% Start des kontinuierlichen Sinus-Signals
disp('Start der Signal- und MQTT-Datenübertragung...');
try
    % Timer für das Sinussignal
    signalTimer = timer(...
        'ExecutionMode', 'fixedRate', ...
        'Period', dt, ...
        'TimerFcn', @(~,~) signalUpdater(true));

    % Timer starten
    start(signalTimer);

    % Endlosschleife für das Senden der Daten
    i = 1;
    while i <= 200
        % Einfache Daten generieren (Zeitstempel hinzufügen)
        timeStampMinusMinutes = (posixtime(datetime('now')));
        timeStampTelegraf_ms = int64((posixtime(datetime('now'))-3600) * 1000);


        normalNow = datetime(timeStampMinusMinutes, 'ConvertFrom', 'posixtime');
        disp(['Normale Zeit: ', datestr(normalNow)]);

        normalEarly = datetime(timeStampTelegraf_ms/1000, 'ConvertFrom', 'posixtime');
        disp(['frühe Zeit: ', datestr(normalEarly)]);
       


        % Aktuelle Sensorwerte abrufen
        [sensor1Value, sensor2Value] = signalUpdater();

        % Sensor1-Daten
        sensor1Data = struct('time', timeStampTelegraf_ms, ...
                             'Sensor1', sensor1Value, ...
                             'location', 'Room1', ...
                             'device', 'DeviceA');

        % Sensor2-Daten
        sensor2Data = struct('time', timeStampTelegraf_ms, ...
                             'Sensor2', sensor2Value, ...
                             'location', 'Room2', ...
                             'device', 'DeviceB');

        % JSON-Daten für Sensor1 senden
        payload1 = jsonencode(sensor1Data);
        write(mqttClient, topic, payload1);
        disp(['Daten für Sensor1 gesendet: ' payload1]);

        % JSON-Daten für Sensor2 senden
        payload2 = jsonencode(sensor2Data);
        write(mqttClient, topic, payload2);
        disp(['Daten für Sensor2 gesendet: ' payload2]);

        % Pause für 1 Sekunde zwischen den Sendungen
        pause(0.1);

        % Zähler erhöhen
        i = i + 1;
    end

    % Timer stoppen
    stop(signalTimer);
    delete(signalTimer);

catch ME
    disp('Skript wurde gestoppt.');
    disp(['Fehler: ' ME.message']);
end

disp('MQTT-Datenversand abgeschlossen.');

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