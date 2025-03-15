%% flexible Funktion zur Erstellung von Custom Queries an die Influx HTTP API

% Testargumente für hier entfernen, sobald in Microservice umgewandelt wird
measurementName = "realData06"; 
queryBucketName = "daten-roh";
orgIDName = "4c0bacdd5f5d7868";
token = 'R-Klt0c_MSuLlVJwvDRWItqX40G_ATERJvr4uy93xgYe1d7MoyHIY_sc_twi4h6GnQdmU9WJI74NbwntEI2luw==';
queryTagMatlabData = "dataType=matlabData";    % Array an Tag-Value-Pairs in Form von jeweils eines Strings
queryTagMetaData = "dataType=matlabMetadata";  % Array an Tag-Value-Pairs in Form von jeweils eines Strings
queryTagEdgeData = "dataType=edgeData";        % Array an Tag-Value-Pairs in Form von jeweils eines Strings

edgeData1 = getEdgeData(measurementName, queryBucketName, orgIDName, token, queryTagEdgeData);

function edgeData = getEdgeData(measurementName, queryBucketName, orgIDName, token, queryTagEdgeData)
    % Erzeuge die URL für die Query-API
    influxURL = sprintf('http://localhost:8086/api/v2/query?orgID=%s', orgIDName);
    
    % Beginne mit dem Flux-Query-String: Filter für Bucket, Measurement und range
    fluxQuery = sprintf('from(bucket: "%s") |> range(start: -inf) |> filter(fn: (r) => r._measurement == "%s"', ...
                          queryBucketName, measurementName);
    
    % Füge für jeden Tag aus queryTagEdgeData einen Filter hinzu.
    % queryTagEdgeData ist ein Cell-Array aus Strings im Format "tagName=tagValue"
    for i = 1:length(queryTagEdgeData)
        parts = strsplit(queryTagEdgeData{i}, '=');
        if numel(parts) ~= 2
            error('Tag %s hat nicht das Format "Name=Value".', queryTagEdgeData{i});
        end
        tagName = strtrim(parts{1});
        tagValue = strtrim(parts{2});
        % Füge den Filter hinzu
        fluxQuery = [fluxQuery sprintf(' and r.%s == "%s"', tagName, tagValue)];
    end
    
    % Schließe die Filter-Funktion ab und behalte nur die gewünschten Spalten
    fluxQuery = [fluxQuery ') |> keep(columns: ["_value", "_field", "_time"])'];
    
    % Debugging: Zeige die gesamte Flux-Abfrage
    fprintf('Generierte Flux-Abfrage:\n%s\n', fluxQuery);
    
    % Erstelle das Payload-Objekt
    payload = struct('query', fluxQuery, 'type', 'flux');
    
    % Konfiguriere die Weboptions mit den benötigten Headern
    options = weboptions(...
        'MediaType', 'application/json', ...
        'HeaderFields', {...
            'Authorization', ['Token ' token]; ...
            'Accept', 'application/csv' } ...
        );
    
    % Sende die Anfrage und erhalte die Antwort (CSV-Format)
    try
        fprintf('Sende Query an InfluxDB...\n');
        edgeData = webwrite(influxURL, payload, options);
        fprintf('Antwort erhalten.\n');
    catch ME
        fprintf('Fehler bei der Anfrage: %s\n', ME.message);
        edgeData = [];
    end
end
