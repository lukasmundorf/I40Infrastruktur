function result = myMicroservice(input)
    % Dies ist die Haupteinstiegsfunktion des Microservices.
    % Hier kannst du mehrere Hilfsfunktionen aufrufen.
    
    % Aufruf der ersten Hilfsfunktion
    intermediateResult = helperFunction1(input);
    
    % Aufruf der zweiten Hilfsfunktion
    result = helperFunction2(intermediateResult);
end

function out = helperFunction1(in)
    % Beispiel einer Hilfsfunktion, die einen Wert berechnet.
    out = in * 2;
end

function finalResult = helperFunction2(val)
    % Eine weitere Hilfsfunktion zur Weiterverarbeitung.
    finalResult = val + 10;
end
