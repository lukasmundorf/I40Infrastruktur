function output = arrayToString_03(inputStr)
    % Überprüfe, ob die Eingabe ein String oder ein char-Array ist
    if ~ischar(inputStr) && ~isstring(inputStr)
        error("Input must be a string or character array.");
    end

    % Unveränderten String zurückgeben
    output = inputStr;
end
