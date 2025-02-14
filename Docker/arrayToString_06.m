function result = arrayToString_06(str1, str2, str3, numArray)
    % Diese Funktion nimmt drei Strings und ein Zahlenarray als Eingabe und gibt einen kombinierten String zurück
    %
    % Eingabe:
    %   str1 - Erster String
    %   str2 - Zweiter String
    %   str3 - Dritter String
    %   numArray - Array von Zahlen, die an den String angehängt werden
    %
    % Ausgabe:
    %   result - Zusammengesetzter String mit angehängtem Zahlenarray
    %
    
    % Zahlenarray in String umwandeln
    numStr = strjoin(string(numArray), ' ');
    
    % Strings zusammenfügen mit Leerzeichen dazwischen und Zahlenarray anhängen
    result = [str1, ' ', str2, ' ', str3, ' ', numStr];
end
