
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
influxURL = 'http://localhost:8086/api/v2/query?orgID=4c0bacdd5f5d7868';
token     = 'R-Klt0c_MSuLlVJwvDRWItqX40G_ATERJvr4uy93xgYe1d7MoyHIY_sc_twi4h6GnQdmU9WJI74NbwntEI2luw==';

%% Flux-Abfrage definieren: Letzte 15 Minuten
fluxQueryMetadata = 'from(bucket: "my-bucket") |> range(start: -inf) |> filter(fn: (r) => r._measurement == "test11" and r.dataType == "metadata")';  %Query für Metadaten
fluxQueryMatlabData = 'from(bucket: "my-bucket") |> range(start: -inf) |> filter(fn: (r) => r._measurement == "test11" and r.dataType == "data")';    %Query für Datensatz aus Matlab

%welche nehmen? => Rechte Seite ändern!
fluxQuery = fluxQueryMetadata;

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
        save('InfluxMatlabMetaDataQuery.mat', 'data');
    else
        response = "Keine Daten übertragen";
    end
catch ME
    fprintf('Fehler bei der Anfrage: %s\n', ME.message);
    response = [];
end
