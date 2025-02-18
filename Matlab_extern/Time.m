
clearvars

% MQTT Client für MATLAB erstellen und konfigurieren
mqttClient = mqttclient("tcp://localhost:1884");

mqttClient.Connected

pause(1)

% Topic definieren
topic = 'test/topic';
time = 1739822745;
normalNow = datetime(time, 'ConvertFrom', 'posixtime');
disp(['Zeit: ', datestr(normalNow)]);
timeStampMinusMinutes = (posixtime(datetime('now')));
disp(int64(timeStampMinusMinutes));


sensor1Data = struct('time', int64(time *1000), ...
                     'Sensor1', 0.05141, ...
                     'location', 'Room1', ...
                     'device', 'DeviceA');


        % JSON-Daten für Sensor1 senden
        payload1 = jsonencode(sensor1Data);
        write(mqttClient, topic, payload1);
        disp(['Daten für Sensor1 gesendet: ' payload1]);

   

disp('MQTT-Datenversand abgeschlossen.');