% Beispiel-Datum (UTC)
dtr = datetime('16-Mar-2025 21:22:03.4338', 'InputFormat', 'dd-MMM-yyyy HH:mm:ss.SSSS', 'TimeZone', 'UTC');
sec_offset = seconds(4.1233);
add = dtr + sec_offset;

% Umrechnung in Nanosekunden
ns_start = unixNanoseconds(dtr);
ns_end   = unixNanoseconds(add);

disp("Startzeit Unix (ns): " + ns_start)
disp("Endzeit Unix (ns):   " + ns_end)
disp("Unterschied (ns):    " + (ns_end - ns_start))



function ns = unixNanoseconds(dtr)
    % Annahme: dtr ist ein datetime-Objekt in UTC
    % Zerlege das Datum in seine Bestandteile:
    dv = datevec(dtr);
    year = dv(1);
    month = dv(2);
    day = dv(3);
    hour = dv(4);
    minute = dv(5);
    sec = dv(6);  % kann einen Bruchteil enthalten

    % Umrechnung in Julian Day (für den gregorianischen Kalender)
    % Formel aus https://en.wikipedia.org/wiki/Julian_day
    a = floor((14 - month) / 12);
    y = year + 4800 - a;
    m = month + 12*a - 3;
    JD = day + floor((153*m + 2) / 5) + 365*y + floor(y/4) - floor(y/100) + floor(y/400) - 32045;
    
    % Unix-Epoch: 1970-01-01 entspricht Julian Day 2440588
    days_since_epoch = JD - 2440588;
    
    % Rechne die vollen Tage in Sekunden um (als int64)
    sec_from_days = int64(days_since_epoch) * int64(86400);
    
    % Zeitanteil des Tages (Stunden, Minuten, volle Sekunden)
    sec_day = int64(hour) * int64(3600) + int64(minute) * int64(60) + int64(floor(sec));
    
    % Bruchteil der Sekunden in Nanosekunden
    frac_sec = sec - floor(sec);
    ns_frac = int64(round(frac_sec * 1e9));
    
    % Gesamte Unixzeit in Nanosekunden
    ns = (sec_from_days + sec_day) * int64(1e9) + ns_frac;
end
