function result = arrayToString_06(str1, str2, str3, str4, str5, str6, str7, str8, str9, str10, ...
    str11, str12, str13, str14, str15, str16, str17, str18, str19, str20, ...
    str21, str22, str23, str24, str25, str26, str27, str28, str29, str30, ...
    str31, str32, str33, str34, str35, str36, str37, numArray, num)
    % Diese Funktion nimmt 37 Strings, ein Zahlenarray und eine einzelne Zahl als Eingabe
    % und gibt einen kombinierten String zurück
    %
    % Eingabe:
    %   str1 - str37 - Einzelne Strings
    %   numArray  - Array von Zahlen
    %   num       - Einzelne Zahl
    %
    % Ausgabe:
    %   result - Zusammengesetzter String mit angehängtem Zahlenarray und einzelner Zahl
    %
    
    % Alle Strings in eine Zelle packen
    strArray = {str1, str2, str3, str4, str5, str6, str7, str8, str9, str10, ...
        str11, str12, str13, str14, str15, str16, str17, str18, str19, str20, ...
        str21, str22, str23, str24, str25, str26, str27, str28, str29, str30, ...
        str31, str32, str33, str34, str35, str36, str37};
    
    % Strings korrekt verbinden
    strCombined = strjoin(strArray, ' ');
    
    % Zahlenarray in String umwandeln und sicherstellen, dass es ein char-Array ist
    numStr = strjoin(arrayfun(@num2str, numArray, 'UniformOutput', false), ' ');
    
    % Gesamtergebnis zusammensetzen
    result = [strCombined, ' ', numStr, ' ', num2str(num)];
end