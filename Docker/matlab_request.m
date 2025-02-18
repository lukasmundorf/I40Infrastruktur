function response = matlab_request()
% queryInfluxDB sendet eine Flux-Abfrage an die InfluxDB v2 API und gibt die Antwort zurück.
%
% Die Funktion verwendet folgende Konfiguration:
%
% URL:
%   http://localhost:8086/api/v2/query?orgID=4c0bacdd5f5d7868
%
% Headers:
%   Content-Type: application/json
%   Authorization: Token ON4VeH32hhjfBTeDkbRL6nlDs-Cy6R4GgvRxWDodQlKv7-CkqQh_dUy5_XaYTj-lxH5afuxNeBzdgaCejmQ34Q==
%   Accept: application/csv
%
% Body:
% {
%   "query": "from(bucket: \"my-bucket\") |> range(start: -15m) |> filter(fn: (r) => r[\"_measurement\"] == \"mqtt/test\") |> filter(fn: (r) => r[\"device\"] == \"DeviceA\") |> filter(fn: (r) => r[\"_field\"] == \"Sensor1\") |> filter(fn: (r) => r[\"location\"] == \"Room1\")",
%   "type": "flux"
% }
%
% Rückgabewert:
%   response - Die Antwort von InfluxDB (im CSV-Format)

    %% Konfiguration
    influxURL = 'http://host.docker.internal:8086/api/v2/query?orgID=4c0bacdd5f5d7868';
    token     = 'ON4VeH32hhjfBTeDkbRL6nlDs-Cy6R4GgvRxWDodQlKv7-CkqQh_dUy5_XaYTj-lxH5afuxNeBzdgaCejmQ34Q==';
    
    %% Flux-Abfrage definieren: Letzte 15 Minuten
    fluxQuery = [...
        'from(bucket: "my-bucket") ' ...
        '|> range(start: -15m) ' ...
        '|> filter(fn: (r) => r["_measurement"] == "mqtt/test") ' ...
        '|> filter(fn: (r) => r["device"] == "DeviceA") ' ...
        '|> filter(fn: (r) => r["_field"] == "Sensor1") ' ...
        '|> filter(fn: (r) => r["location"] == "Room1")'];
    
    %% Payload vorbereiten
    payload = struct(...
        'query', fluxQuery, ...
        'type', 'flux');
    
    %% Weboptions konfigurieren
    options = weboptions(...
    'MediaType', 'application/json', ...
    'HeaderFields', { ...
        'Authorization', ['Token ' token]; ...
        'Accept', 'application/csv' } ...
    );
    
    %% Anfrage senden
    try
        fprintf('Sende Anfrage an InfluxDB...\n');
        data = webwrite(influxURL, payload, options);
        %data = [];
        fprintf('Antwort erhalten:\n');
        disp(data);
        if ~isempty(data)
            response = "Erfolg";
        else
            response = "Keine Daten übertragen";
        end
    catch ME
        fprintf('Fehler bei der Anfrage: %s\n', ME.message);
        response = [];
    end
end
