% rhs = { {'string1', 'string2', 'string3'}, [1.23, 4.56, 7.89] };
% output = parse_cell_array(rhs);
% disp(output);





function output = arrayToString_02(rhs)
    % rhs wird als Cell-Array erwartet
    if ~iscell(rhs)
        error("Input must be a cell array.");
    end
    
    % Strings extrahieren (1. Element)
    if iscell(rhs{1})
        strArray = strjoin(rhs{1}, ', '); % Strings mit Komma verbinden
    else
        strArray = "Invalid format for strings";
    end
    
    % Zahlen extrahieren (2. Element)
    if isnumeric(rhs{2})
        numArray = num2str(rhs{2}); % Zahlen in String umwandeln
    else
        numArray = "Invalid format for numbers";
    end
    
    % Gesamtausgabe zusammenstellen
    output = sprintf("Strings: [%s] | Numbers: [%s]", strArray, numArray);
end
