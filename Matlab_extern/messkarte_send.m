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
a.Rate=1000;

a.addinput("DT9836(00)",0,"Voltage"); % add more channels as needed
a.addinput("DT9836(00)",1,"Voltage"); % add more channels as needed
a.addinput("DT9836(00)",2,"Voltage"); % add more channels as needed
a.addinput("DT9836(00)",3,"Voltage"); % add more channels as needed
a.addinput("DT9836(00)",4,"Voltage"); % add more channels as needed
a.addinput("DT9836(00)",5,"Voltage"); % add more channels as needed
a.addinput("DT9836(00)",6,"Voltage"); % add more channels as needed
a.addinput("DT9836(00)",7,"Voltage"); % add more channels as needed
a.addinput("DT9836(00)",8,"Voltage"); % add more channels as needed
a.addinput("DT9836(00)",9,"Voltage"); % add more channels as needed
a.addinput("DT9836(00)",10,"Voltage"); % add more channels as needed
a.addinput("DT9836(00)",11,"Voltage"); % add more channels as needed

disp(a.Channels)

start(a,"continuous");


pause(0.2);

disp([a.NumScansAvailable, a.NumScansAcquired]);

[ScanData, triggerTime] = a.read("all","OutputFormat","Timetable");
ScanData_acc = ScanData;
disp([a.NumScansAvailable, a.NumScansAcquired]);
tic
% Anzahl der Zeilen in der Timetable
nRows = height(ScanData_acc);
% Bei Timetables zählt width() nur die Daten-Spalten (also die Channels)
nChannels = width(ScanData_acc);  

% Preallokation des struct-Arrays
data(nRows) = struct();

for i = 1:nRows
    % Berechnung der Messzeit: triggerTime + relativer Zeitwert aus der Timetable
    measurementTime = triggerTime + ScanData_acc.Time(i);
    % disp(measurementTime);
    % Umrechnung in Unix-Zeitstempel in Millisekunden (13 Ziffern)
    unixTime = ((posixtime(measurementTime) - 3600)* 1000);
    % disp(int64(unixTime));
    data(i).time = unixTime;
    
    % Dynamische Erstellung der Channel-Felder, die bei 0 beginnen
    for j = 1:nChannels
        fieldName = sprintf('voltage%d', j-1);
        % Zugriff: Die Channels sind in den Spalten der Timetable enthalten
        data(i).(fieldName) = ScanData_acc{i, j};
    end
end
elapsed =toc;
disp(elapsed);
% Umwandlung in JSON-Format
jsonStr = jsonencode(data);
% disp(jsonStr)

write(mqttClient, topic, jsonStr);
% disp(['Daten für alle Sensoren gesendet: ' jsonStr]);


disp('MQTT-Datenversand abgeschlossen.');




% pause(1);
% ScanData = a.read("all","OutputFormat","Timetable");
% ScanData_acc = [ScanData_acc;ScanData];



% scanData = read(a,5);
% disp(a);
% disp(scanData);
% disp(scanData.Time);
% disp(scanData.(1));
% 

