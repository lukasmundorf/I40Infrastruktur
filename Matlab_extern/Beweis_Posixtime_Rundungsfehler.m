dtr = datetime('11-Mar-2025 21:22:03.438', 'InputFormat', 'dd-MMM-yyyy HH:mm:ss.SSS');
sec = seconds(4.1234);

% Setze explizit die Zeitzone auf UTC, um den Fehler zu vermeiden
dtr.TimeZone = 'UTC'; 

dtr.Format = 'dd-MMM-yyyy HH:mm:ss.SSSSS';
add = dtr + sec; 
add.Format = 'dd-MMM-yyyy HH:mm:ss.SSSSS';

% Berechnung mit posixtime()
timeVec = int64(posixtime(dtr) * 1e9); % Umrechnung in Nanosekunden
timeVec2 = int64(posixtime(add) * 1e9);
disp("Startzeit Posix: " + timeVec);
disp("Endzeit Posix " + timeVec2);
disp("Unterschied Posix " + (timeVec2 - timeVec));

% Berechnung mit realPosixtime() - ohne zusätzliche Multiplikation
realtimeVec = realPosixtime(dtr);
realtimeVec2 = realPosixtime(add);
disp("Startzeit Posix real: " + realtimeVec);
disp("Endzeit Posix real: " + realtimeVec2);
disp("Unterschied Posix real: " + (realtimeVec2 - realtimeVec));

% Korrigierte Funktion für genaue Unixzeit in ns
function output = realPosixtime(date)
    epoch = datetime(1970,1,1,0,0,0, 'TimeZone', 'UTC');
    
    % Sicherstellen, dass das Datum ebenfalls in UTC ist
    if isempty(date.TimeZone)
        date.TimeZone = 'UTC';
    end
    
    % Differenz in Nanosekunden berechnen
    output = milliseconds(date - epoch) * 1e6;
end
