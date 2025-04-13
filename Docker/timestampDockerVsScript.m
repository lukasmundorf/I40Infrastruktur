function timestampDockerVsScript()
    % Erstelle aktuellen Zeitstempel in UTC
    utcTimestamp = datetime('now', TimeZone='local');

    % Umwandlung in Unixzeit (Sekunden seit 1970-01-01)
    unixTimestamp = posixtime(utcTimestamp);

    % Ausgabe
    disp("Aktueller UTC-Zeitstempel:");
    disp(utcTimestamp);
    disp("Entsprechender Unixzeitstempel (in Sekunden seit 1970-01-01):");
    disp(unixTimestamp);
end