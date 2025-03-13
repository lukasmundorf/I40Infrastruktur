a= createTestQuery();
save('ValidationTestQuery.mat', 'a');
function testQuery = createTestQuery()
% createTestQuery - Erzeugt eine Testquery-Tabelle im Format der InfluxDB-Daten.
%
% Das Format:
%   - x_field: Enthält den Kanalnamen, z.B. 'voltage0', 'voltage1', ...,
%              blockweise sortiert (zuerst alle Werte von voltage0, dann voltage1, usw.)
%   - x_value: Enthält Messwerte, die für jeden Kanal von 0 bis 100 hochzählen.
%   - x_time : Ein Zeitstempel, der für jeden Messwert inkrementell ansteigt.
%
% Beispiel:
%   >> testQuery = createTestQuery();
%   >> head(testQuery)
%
% Es werden 12 Kanäle (0 bis 11) und 101 Samples pro Kanal erzeugt.

    nChannels = 12;    % Kanäle 0 bis 11
    nSamples  = 101;   % Werte von 0 bis 100
    
    % Vorallgemeine Arrays initialisieren
    totalRows = nChannels * nSamples;
    x_field = cell(totalRows, 1);
    x_value = zeros(totalRows, 1);
    x_time  = repmat(datetime('2025-03-12 12:00:00'), totalRows, 1); % Basiszeitpunkt

    % Index zum Befüllen der Arrays
    idx = 1;
    for ch = 0:(nChannels - 1)
        for sample = 0:(nSamples - 1)
            % Erzeuge den Kanalnamen, z.B. "voltage0"
            x_field{idx} = sprintf('voltage%d', ch);
            % Messwert: von 0 bis 100 hochzählen (linear)
            x_value(idx) = sample;
            % Optional: x_time wird als Basiszeit plus Sekunden (sample) definiert.
            x_time(idx) = datetime('2025-03-12 12:00:00') + seconds(sample);
            idx = idx + 1;
        end
    end

    % Tabelle erstellen
    testQuery = table(x_field, x_value, x_time);
end
