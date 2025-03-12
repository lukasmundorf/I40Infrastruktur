clearvars;
daqreset;

% MQTT Client für MATLAB erstellen und konfigurieren
mqttClient = mqttclient("tcp://localhost:1884");

mqttClient.Connected

pause(1/100);

% Topic definieren
topic = 'test/topic';

notes = "abcde";
a = daq('dt');
a.Rate=10000;

a.addinput("DT9836(00)",0,"Voltage"); % add more channels as needed
a.addinput("DT9836(00)",1,"Voltage"); % add more channels as needed
a.addinput("DT9836(00)",2,"Voltage"); % add more channels as needed
a.addinput("DT9836(00)",3,"Voltage"); % add more channels as needed
a.addinput("DT9836(00)",4,"Voltage"); % add more channels as needed
a.addinput("DT9836(00)",5,"Voltage"); % add more channels as needed
a.addinput("DT9836(00)",7,"Voltage"); % add more channels as needed
a.addinput("DT9836(00)",8,"Voltage"); % add more channels as needed
a.addinput("DT9836(00)",9,"Voltage"); % add more channels as needed
a.addinput("DT9836(00)",10,"Voltage"); % add more channels as needed

disp(a.Channels)

start(a,"continuous");


pause(0.2);

disp([a.NumScansAvailable, a.NumScansAcquired]);

[ScanData, triggerTime] = a.read("all","OutputFormat","Timetable");
disp(triggerTime);
pause(2);
[ScanData2, triggerTime2] = a.read("all","OutputFormat","Timetable");
disp(triggerTime2);

% Nehme an, ScanData wurde bereits eingelesen und enthält die Zeitspalte "Time"
% Konvertiere die Zeitspalte in Sekunden (double) mittels posixtime:

% Stelle sicher, dass du "format long g" verwendest, um alle signifikanten Stellen anzuzeigen:

