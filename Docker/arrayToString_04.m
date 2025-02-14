function result = arrayToString_04(inputArray)
    % Debug: Anzahl der Eingabeargumente anzeigen
    disp("Anzahl der Eingabeargumente:");
    disp(nargin);

    % Falls die Eingabe ein Zell-Array ist, in ein String-Array umwandeln
    if iscell(inputArray)
        inputArray = string(inputArray);
    end

    % Überprüfen, ob die Eingabe jetzt ein String-Array ist
    if ~isstring(inputArray)
        error('Eingabe muss ein Zell-Array mit Strings oder ein String-Array sein.');
    end

    % Strings zu einem zusammenhängenden String verbinden
    result = strjoin(inputArray, ' '); % Leerzeichen als Trennzeichen
end