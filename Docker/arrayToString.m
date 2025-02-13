function infoStr = arrayToString(sampleRate, command, sensitivities, units, names, directions)
    % measurementInfo erstellt einen String, der alle Messparameter zusammenfasst.
    %
    % Eingaben:
    %   sampleRate   - Abtastrate (Double)
    %   command      - Befehl ("Start" oder "Stop") (String)
    %   sensitivities- Array mit Sensitivitätswerten (Double)
    %   units        - Array mit Einheiten (Cell-Array von Strings)
    %   names        - Array mit Namen (Cell-Array von Strings)
    %   directions   - Array mit Messrichtungen (Cell-Array von Strings)
    %
    % Ausgabe:
    %   infoStr      - String, der alle Informationen enthält
    
    % Erstelle den Basis-String mit SampleRate und Command
    infoStr = sprintf('SampleRate: %g\nBefehl: %s\n', sampleRate, command);
    
    % Sensitivitäten hinzufügen
    infoStr = [infoStr, 'Sensitivitäten: '];
    for i = 1:length(sensitivities)
        infoStr = [infoStr, sprintf('%g', sensitivities(i))];
        if i < length(sensitivities)
            infoStr = [infoStr, ', '];
        end
    end
    infoStr = [infoStr, '\n'];
    
    % Einheiten hinzufügen
    infoStr = [infoStr, 'Einheiten: '];
    for i = 1:length(units)
        infoStr = [infoStr, units{i}];
        if i < length(units)
            infoStr = [infoStr, ', '];
        end
    end
    infoStr = [infoStr, '\n'];
    
    % Namen hinzufügen
    infoStr = [infoStr, 'Namen: '];
    for i = 1:length(names)
        infoStr = [infoStr, names{i}];
        if i < length(names)
            infoStr = [infoStr, ', '];
        end
    end
    infoStr = [infoStr, '\n'];
    
    % Messrichtungen hinzufügen
    infoStr = [infoStr, 'Messrichtungen: '];
    for i = 1:length(directions)
        infoStr = [infoStr, directions{i}];
        if i < length(directions)
            infoStr = [infoStr, ', '];
        end
    end
    
    end
    