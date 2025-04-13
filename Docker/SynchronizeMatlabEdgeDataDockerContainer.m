%% Hauptskript: Synchronisation der Daten

function response = SynchronizeMatlabEdgeDataDockerContainer(measurementName, queryBucketName, writeBucketName, orgIDName, sendBatchSize, token)

%% Testparameter (zum Testen – in der finalen Microservice-Version entfernen)
% measurementName         = "DemoData01"; 
% queryBucketName         = "daten-roh";
% writeBucketName         = "daten-aufbereitet";
% orgIDName               = "4c0bacdd5f5d7868";
% sendBatchSize           = 5000;
% token                   = 'R-Klt0c_MSuLlVJwvDRWItqX40G_ATERJvr4uy93xgYe1d7MoyHIY_sc_twi4h6GnQdmU9WJI74NbwntEI2luw==';
queryTagMatlabData      = "dataType=matlabData";      
queryTagMatlabMetaData  = "dataType=matlabMetadata";  
queryTagEdgeData        = "dataType=edgeData";        
queryTagEdgeMetaData    = "dataType=edgeMetadata";  
writeTagSyncedData      = "dataType=synchronizedEdgeMatlabData";
writeTagSyncedMatlabMetaData  = "dataType=synchronizedMatlabMetaData";
writeTagSyncedEdgeMetaData  = "dataType=synchronizedEdgeMetaData";

%% Daten importieren und vorbereiten

% Metadaten laden und strukturieren
measurement_settings = getStructuredMatlabMetadata(measurementName, queryBucketName, orgIDName, token, queryTagMatlabMetaData); 
additionalMetadata   = getStructuredEdgeMetadata(measurementName, queryBucketName, orgIDName, token, queryTagEdgeMetaData); 

% SampleRates aus den Metadaten extrahieren
sampleRate_Matlab = measurement_settings.Samplerate;
sampleRate_Edge   = additionalMetadata.sampleRate_Edge;

% Messdaten laden
StructuredMatlabData = getStructuredInfluxData(sampleRate_Matlab, measurementName, queryBucketName, orgIDName, token, queryTagMatlabData);
StructuredEdgeData   = getStructuredInfluxData(sampleRate_Edge, measurementName, queryBucketName, orgIDName, token, queryTagEdgeData);

% Sortiere die Spalten beider Timetables entsprechend der gewünschten Kanalreihenfolge
numActiveChannels = width(StructuredMatlabData);
MatlabChannelNames_rightOrder = measurement_settings.ChannelNameOrdered;
StructuredMatlabData = sortTableColumns(StructuredMatlabData, MatlabChannelNames_rightOrder);
StructuredEdgeData   = sortTableColumns(StructuredEdgeData, additionalMetadata.EdgeChannelNames_rightOrder);

% Setze die DimensionNames auf "Time" (erste Dimension)
dNames = StructuredMatlabData.Properties.DimensionNames;
dNames{1} = 'Time';
StructuredMatlabData.Properties.DimensionNames = dNames;

dNames = StructuredEdgeData.Properties.DimensionNames;
dNames{1} = 'Time';
StructuredEdgeData.Properties.DimensionNames = dNames;

clearvars -except timezoneCorrection writeTagSyncedMatlabMetaData additionalMetadata writeTagSyncedEdgeMetaData StructuredMatlabData StructuredEdgeData measurement_settings numActiveChannels measurementName writeBucketName orgIDName token sendBatchSize writeTagSyncedData additionalMetadata sampleRate_Edge sampleRate_Matlab

% % Prüfe, ob die erste Variable in StructuredMatlabData "Sync_Signal" heißt
% matlabFirstVar = StructuredMatlabData.Properties.VariableNames{1};
% isMatlabSync = strcmp(matlabFirstVar, 'Sync_Signal');
% 
% % Prüfe, ob die erste Variable in StructuredEdgeData "sync_signal" heißt
% edgeFirstVar = StructuredEdgeData.Properties.VariableNames{1};
% isEdgeSync = strcmp(edgeFirstVar, 'sync_signal');
% %Falls Ja, entferne ersten Eintrag in Metadaten. Sonst Fehlermeldung
% if isMatlabSync && isEdgeSync
%     % --- Teil 1: measurement_settings ---
%     fieldsToTrimMeasurement = { ...
%         'MeasuredQuantity', ...
%         'Direction', ...
%         'ChannelNameOrdered', ...
%         'CalculatedUnit', ...
%         'AdditionalNotes' ...
%         };
% 
%     for i = 1:numel(fieldsToTrimMeasurement)
%         fieldName = fieldsToTrimMeasurement{i};
%         measurement_settings.(fieldName)(1) = [];  % Erstes Element löschen
%     end
% 
%     % --- Teil 2: additionalMetadata ---
%     fieldsToTrimAdditional = { ...
%         'EdgeChannelNames_rightOrder', ...
%         'EdgeVariableUnits_rightOrder' ...
%         };
% 
%     for i = 1:numel(fieldsToTrimAdditional)
%         fieldName = fieldsToTrimAdditional{i};
%         additionalMetadata.(fieldName)(1) = [];  % Erstes Element löschen
%     end
% 
% 
% else
%     disp('Bitte Channels neu verkabeln, sodass Synchronisierungsskript laufen kann')
%     response = "Fehler: Sync Signal nicht an Channel 0";
%     return
% end


%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Synchronisation von Florian Oexle
% Synchronisationssignal muss an erster Stelle sein!
messdaten_syncr = SyncMatlabEdgeData(StructuredMatlabData, StructuredEdgeData);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Senden der synchronisierten Daten in Tabelle an InfluxDB in Batches
disp('Sende Daten an InfluxDB...')
statusMessage = convertAndSendSyncTable(measurementName, writeBucketName, orgIDName, token, sendBatchSize, writeTagSyncedData, messdaten_syncr);
disp(statusMessage);
disp('Sende Metadaten an InfluxDB...')
statusMessage2 = convertAndSendSyncMetadata(measurementName, measurement_settings, additionalMetadata, writeBucketName, orgIDName, token, writeTagSyncedMatlabMetaData, writeTagSyncedEdgeMetaData, messdaten_syncr, numActiveChannels);
disp(statusMessage2);
statusMessage3 = 'Synchronisierung Erfolgreich';
disp(statusMessage3);
response = statusMessage3;
end

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Funktionen
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Funktion: getStructuredMatlabMetadata
% Lädt und strukturiert Matlab-Metadaten aus einer InfluxDB-Abfrage
%
% Rückgabe:
%   metadataStruct - Struct mit den Feldern:
%     - MeasuredQuantity (1xN String)
%     - Direction        (1xN String)
%     - SensitivityValue (1xN double)
%     - SensitivityUnit  (1xN String)
%     - AdditionalNotes  (1xN String)
%     - Samplerate       (Skalar, Abtastrate)
function metadataStruct = getStructuredMatlabMetadata(measurementName, queryBucketName, orgIDName, token, queryTagMatlabMetaData)
    % 1) Lade Rohdaten aus InfluxDB
    rawData = getInfluxData(measurementName, queryBucketName, orgIDName, token, queryTagMatlabMetaData);

    % 2) Sortiere die Tabelle anhand der numerischen Reihenfolge
    metadataTabelle = sortrows(rawData, 'channelNumber');

    % 3) Fülle das Metadata-Struct
    metadataStruct = struct();
    metadataStruct.MeasuredQuantity = string(metadataTabelle.measuredQuantity)';
    metadataStruct.Direction        = string(metadataTabelle.messrichtung)';
    metadataStruct.ChannelNameOrdered = string(metadataTabelle.x_value)';
    metadataStruct.CalculatedUnit  = string(metadataTabelle.einheit)';
    metadataStruct.AdditionalNotes  = string(metadataTabelle.notizen)';
    metadataStruct.Samplerate       = metadataTabelle.sampleRate(1);
end

%% Funktion: getStructuredEdgeMetadata
% Lädt und strukturiert Edge-Metadaten aus einer InfluxDB-Abfrage
%
% Rückgabe:
%   additionalMetadataStruct - Struct mit den Feldern:
%     - sortedData                     (sortierte Rohdaten)
%     - EdgeChannelNames_rightOrder    (String-Array, sortierte Kanalnamen)
%     - EdgeVariableUnits_rightOrder   (String-Array, sortierte Einheiten, "NV" wird ersetzt)
%     - sampleRate_Edge                (Abtastrate der Edge-Daten)
function additionalMetadataStruct = getStructuredEdgeMetadata(measurementName, queryBucketName, orgIDName, token, queryTagEdgeMetaData)
    % 1) Abfrage der Rohdaten
    rawData = getInfluxData(measurementName, queryBucketName, orgIDName, token, queryTagEdgeMetaData);
    
    % 2) Bestimme die numerische Reihenfolge aus 'rightChannelOrder'
    rawData.numericOrder = str2double(erase(rawData.rightChannelOrder, 'ch'));
    
    % 3) Sortiere die Daten nach dieser Reihenfolge
    sortedData = sortrows(rawData, 'numericOrder');
    sortedData.numericOrder = [];  % Entferne Hilfsspalte
    
    % 4) Extrahiere Kanalnamen und Einheiten als String-Arrays
    EdgeChannelNames_rightOrder = string(sortedData.x_value);
    EdgeVariableUnits_rightOrder = string(sortedData.einheit);
    % Ersetze "NV" durch einen leeren String
    EdgeVariableUnits_rightOrder(EdgeVariableUnits_rightOrder == "NV") = "";
    
    % 5) Erstelle das Rückgabe-Struct
    additionalMetadataStruct.sortedData                   = sortedData;
    additionalMetadataStruct.EdgeChannelNames_rightOrder    = EdgeChannelNames_rightOrder;
    additionalMetadataStruct.EdgeVariableUnits_rightOrder   = EdgeVariableUnits_rightOrder;
    additionalMetadataStruct.sampleRate_Edge                = sortedData.sampleRate(1);
end

%% Funktion: getStructuredInfluxData
% Formatiert abgefragte Messdaten aus InfluxDB zu einer Timetable.
%
% Parameter:
%   sampleRate       - Abtastrate (Hz)
%   measurementName  - Name des Measurements
%   queryBucketName  - Bucket-Name für die Abfrage
%   orgIDName        - Organisation/ID
%   token            - Authentifizierungstoken
%   queryTags        - Tag-Filter (z.B. "dataType=...")
%
% Rückgabe:
%   dataTT - Timetable mit Spalten entsprechend der Kanäle
function dataTT = getStructuredInfluxData(sampleRate, measurementName, queryBucketName, orgIDName, token, queryTags)
    % 1) Abfrage der Messdaten
    dataTable = getInfluxData(measurementName, queryBucketName, orgIDName, token, queryTags);

    % 2) Ermittlung der eindeutigen Kanäle (in der Reihenfolge des Auftretens)
    uniqueChannelsStable = unique(dataTable.x_field, 'stable');
    nUnique = numel(uniqueChannelsStable);
    
    % 3) Bestimme die Anzahl der Samples pro Kanal (Annahme: gleiche Anzahl pro Kanal)
    nRows    = height(dataTable);
    nSamples = nRows / nUnique;
    
    % 4) Organisiere die Kanaldaten in einem Zellenarray
    channelBlocks = cell(1, nUnique);
    for i = 1:nUnique
        blockStart = (i-1)*nSamples + 1;
        blockEnd   = i*nSamples;
        channelBlocks{i} = dataTable.x_value(blockStart:blockEnd);
    end
    
    % 5) Erstelle eine Zeitachse basierend auf der Abtastrate
    Fs = sampleRate;          % z.B. 1000 Hz
    dt = 1 / Fs;              % Zeitintervall
    timeArray = seconds((0:nSamples-1)' * dt);
    
    % 6) Initialisiere die Timetable und füge Kanaldaten ein
    dataTT = timetable(timeArray);
    for i = 1:nUnique
        colName = uniqueChannelsStable{i};
        dataTT.(colName) = channelBlocks{i};  %doppelte Definition, sowohl Spalte als auch Spalteninhalt
    end
    
    % 7) Zusätzliche Timetable-Eigenschaften (optional)
    dataTT.Properties.SampleRate = Fs;
end

%% Funktion: getMatlabValidationData
% Lädt Testdaten aus einer Datei zur Validierung
function matlabData = getMatlabValidationData()
    matlabData = load('ValidationTestQuery.mat');
end

%% Funktion: getInfluxData
% Führt eine Abfrage bei InfluxDB aus und gibt die resultierende Tabelle zurück.
%
% Parameter:
%   measurementName  - Name des Measurements
%   queryBucketName  - Bucket-Name
%   orgIDName        - Organisation/ID
%   token            - Authentifizierungstoken
%   queryTags        - Filter-Tags im Format "Name=Value"
%
% Rückgabe:
%   influxData - Abfrageergebnis (als Tabelle)
function influxData = getInfluxData(measurementName, queryBucketName, orgIDName, token, queryTags)
    % Bestimme, ob nur _value, _field und _time abgefragt werden sollen
    if any(strcmp(queryTags, 'dataType=matlabMetadata')) || any(strcmp(queryTags, 'dataType=edgeMetadata'))
        onlyValueFieldTimeQuery = false;
    else
        onlyValueFieldTimeQuery = true;
    end

    % Erstelle die URL für die InfluxDB-Query-API
    influxURL = sprintf('http://host.docker.internal:8086/api/v2/query?orgID=%s', orgIDName);

    % Erstelle den initialen Flux-Query-String
    fluxQuery = sprintf('from(bucket: "%s") |> range(start: -inf) |> filter(fn: (r) => r._measurement == "%s"', ...
                        queryBucketName, measurementName);

    % Füge jeden Tag-Filter hinzu
    for i = 1:length(queryTags)
        parts   = strsplit(queryTags{i}, '=');
        if numel(parts) ~= 2
            error('Tag %s hat nicht das Format "Name=Value".', queryTags{i});
        end
        tagName  = strtrim(parts{1});
        tagValue = strtrim(parts{2});
        fluxQuery = [fluxQuery sprintf(' and r.%s == "%s"', tagName, tagValue)];
    end
    fluxQuery = [fluxQuery ')'];  % Schließe den Filter ab

    % Falls nur bestimmte Spalten abgefragt werden sollen, wende einen keep-Filter an
    if onlyValueFieldTimeQuery
        fluxQuery = [fluxQuery ' |> keep(columns: ["_value", "_field", "_time"])'];
    end

    % Ausgabe des generierten Flux-Query (Debugging)
    fprintf('Generierte Flux-Abfrage:\n%s\n', fluxQuery);

    % Erstelle das Payload-Objekt
    payload = struct('query', fluxQuery, 'type', 'flux');

    % Konfiguriere die Weboptions (HTTP-Header etc.)
    options = weboptions(...
        'MediaType', 'application/json', ...
        'HeaderFields', {...
            'Authorization', ['Token ' token]; ...
            'Accept', 'application/csv' } ...
    );

    % Sende die Abfrage an InfluxDB und erhalte die Antwort (CSV-Format)
    try
        fprintf('Sende Query an InfluxDB...\n');
        influxData = webwrite(influxURL, payload, options);
        fprintf('Antwort erhalten.\n');
    catch ME
        fprintf('Fehler bei der Anfrage: %s\n', ME.message);
        influxData = [];
    end
end

%% Funktion: convertAndSendSyncTable
% Konvertiert eine synchronisierte Tabelle in das Line Protocol-Format und
% sendet die Daten in Batches an InfluxDB.
%
% Parameter:
%   measurementName - Name des Measurements
%   writeBucketName - Bucket, in den geschrieben werden soll
%   orgIDName       - Organisation/ID
%   token           - Authentifizierungstoken
%   batchSize       - Anzahl der Zeilen pro Batch
%   writeTag        - Tag-Information als Teil des Measurements
%   finishedTableSynced - Objekt, das die synchronisierte Tabelle enthält
%
% Rückgabe:
%   statusMessage - Statusmeldung zum Schreibvorgang
function statusMessage = convertAndSendSyncTable(measurementName, writeBucketName, orgIDName, token, batchSize, writeTag, dataTable)
 
    % Konfiguriere Zeitstempel:
    unixNowNs = posixtime(datetime('now', TimeZone='UTC')) * 1e9;  % Aktuelle Zeit in UTC, Nanosekunden
    sampleRate = dataTable.Properties.SampleRate;
    timeStepNs = 1e9 / sampleRate;  % Zeitinkrement pro Zeile
    
    [numRows, ~] = size(dataTable);
    columnNames = dataTable.Properties.VariableNames;
    numBatches = ceil(numRows / batchSize);

    % Vektorisiere die Zeitstempel
    timestampsNs = int64(unixNowNs + (0:numRows-1)' * timeStepNs);

    overallTimer = tic;  % Starte Timer für Zeitabschätzung

    % Sende die Daten in Batches, kann evtl noch optimiert werden
    for batchIdx = 1:numBatches
        startIdx = (batchIdx - 1) * batchSize + 1;
        endIdx   = min(batchIdx * batchSize, numRows);
        batchTimestamps = timestampsNs(startIdx:endIdx);

        % Extrahiere Batch-Daten als Matrix
        batchData = dataTable{startIdx:endIdx, :};

        % Konvertiere die Daten in Strings und erstelle Feld-Zuordnungen
        batchDataStr = string(batchData);
        batchFields  = columnNames + "=" + batchDataStr;
        batchFieldsStr = join(batchFields, ",", 2);
        
        % Erstelle das Line Protocol: measurement,tag field1=value1,... timestamp
        lineProtocol = measurementName + "," + writeTag + " " + batchFieldsStr + " " + string(batchTimestamps);
        writeBatch = join(lineProtocol, newline);  % Kombiniere Zeilen
        
        % Sende den Batch an InfluxDB
        statusMessage = sendLineProtocolToInflux(token, writeBucketName, orgIDName, writeBatch);

        % Berechne und gebe die verbleibende Zeit aus
        elapsedTime = toc(overallTimer);
        avgTimePerBatch = elapsedTime / batchIdx;
        remainingBatches = numBatches - batchIdx;
        estimatedRemainingTime = avgTimePerBatch * remainingBatches;
        hours   = floor(estimatedRemainingTime / 3600);
        minutes = floor(mod(estimatedRemainingTime, 3600) / 60);
        seconds = mod(estimatedRemainingTime, 60);

        if strcmp(statusMessage, 'Write abgeschlossen')
            fprintf('Batch %d/%d mit %d Zeilen gesendet. Geschätzte verbleibende Zeit: %d h %d m %.0f s.\n', ...
                batchIdx, numBatches, endIdx - startIdx + 1, hours, minutes, seconds);
        else
            disp(statusMessage)
        end
    end
end

%% Funktion: sendLineProtocolToInflux
% Sendet einen Daten-Batch im Line Protocol an InfluxDB.
%
% Parameter:
%   token         - Authentifizierungstoken
%   writeBucketName - Bucket, in den geschrieben wird
%   orgIDName     - Organisation/ID
%   writeBatch    - String mit dem Batch im Line Protocol
%
% Rückgabe:
%   statusMessage - Statusmeldung zum Schreibvorgang
function statusMessage = sendLineProtocolToInflux(token, writeBucketName, orgIDName, writeBatch)
    % Erstelle die URL für den Write-Endpunkt
    influxURL = sprintf('http://host.docker.internal:8086/api/v2/write?org=%s&bucket=%s&precision=ns', orgIDName, writeBucketName);

    % Konfiguriere die Weboptions für den POST-Request
    options = weboptions(...
        'RequestMethod', 'post', ...
        'MediaType', 'text/plain', ...
        'HeaderFields', {...
            'Authorization', ['Token ' token]; ...
            'Content-Type', 'text/plain; charset=utf-8'} ...
    );

    % Sende den Request
    try
        fprintf('Sende Write-Anfrage an InfluxDB...\n');
        response = webwrite(influxURL, writeBatch, options);
        disp(response);
        statusMessage = 'Write abgeschlossen';
    catch ME
        statusMessage = sprintf('Fehler: %s', ME.message);
    end
end

%% Funktion: sortTableColumns
% Sortiert die Spalten einer Timetable anhand eines vorgegebenen String-Arrays.
%
% Parameter:
%   tt           - Timetable, dessen Spalten sortiert werden sollen
%   desiredOrder - String-Array mit der gewünschten Reihenfolge der Spalten
%
% Rückgabe:
%   tt - Timetable mit neu sortierten Spalten
function tt = sortTableColumns(tt, desiredOrder)
    % Überprüfe, ob alle gewünschten Spalten in der Timetable vorhanden sind
    fehlendeSpalten = setdiff(desiredOrder, tt.Properties.VariableNames);
    if ~isempty(fehlendeSpalten)
        error('Die folgenden Spalten fehlen in der Timetable: %s', join(fehlendeSpalten, ', '));
    end
    % Sortiere die Spalten gemäß der gewünschten Reihenfolge
    tt = tt(:, desiredOrder);
end


%% Funktion, um Metadaten (matlab und edge) zur Tabelle in Influx zu schreiben
function statusMessage = convertAndSendSyncMetadata(measurementName, measurement_settings, additionalMetadata, writeBucketName, orgIDName, token, ...
    writeTagSyncedMatlabMetaData, writeTagSyncedEdgeMetaData, dataTable, numActiveChannels)
% convertAndSendSyncMetadata - Konvertiert sowohl Matlab- als auch Edge-Metadaten
%                               in das Line Protocol und sendet sie an InfluxDB.
%
% Eingabeparameter:
%   measurementName              - Name des Measurements (String/char)
%   measurement_settings         - Struct mit den Metadaten, insbesondere:
%                                  .MeasuredQuantity (String-Array)
%                                  .Direction (String-Array)
%   writeBucketName              - Bucket, in den geschrieben wird
%   orgIDName                    - Organisation/ID
%   token                        - InfluxDB-Token
%   sendBatchSize                - Batch-Größe (wird hier noch nicht verwendet)
%   writeTagSyncedMatlabMetaData - Tag für synchronisierte Matlab-Metadaten (z.B. "dataType=matlabMetadata")
%   writeTagSyncedEdgeMetaData   - Tag für synchronisierte Edge-Metadaten (z.B. "dataType=edgeMetadata")
%   dataTableObj                 - Objekt, aus dem die Tabelle extrahiert wird 
%                                  (hier: dataTableObj.messdaten_syncr)
%   numActiveChannels            - Gesamtzahl aktiver Kanäle; es werden die ersten numActiveChannels genutzt,
%                                  wobei das erste Element in MeasuredQuantity und Direction übersprungen wird.
%
% Rückgabe:
%   statusMessage                - Rückmeldung, ob der Schreibvorgang erfolgreich war.
    
    % 00)SampleRate aus dataTable entnehmen
    sampleRate = dataTable.Properties.SampleRate;
    % 1) measurementName bereinigen
    measurementName = char(measurementName);
    measurementName = strrep(measurementName, ' ', '_');
    if isempty(measurementName)
        measurementName = 'none';
    end

    % 2) Matlab-Metadaten-Zeilen erstellen
    chosenTagMatlab = char(writeTagSyncedMatlabMetaData);
    numMatlabLines = numActiveChannels;  % Es werden die ersten numActiveChannels-1 Zeilen erzeugt, da Synchronisierungschannel nicht mehr gesendet wird
    matlabLines = cell(numMatlabLines, 1);
    
    % Basis-Zeitstempel (aktuelle Unix-Zeit minus 1h) und Zeitinkrement
    timestamp_base = posixtime(datetime('now',TimeZone='UTC')) * 1e9;  % UTC-Timestamp!
    timestamp_increment = 1e5;
    
    for i = 1:numMatlabLines
        timestamp = int64(timestamp_base + (i-1) * timestamp_increment);
        
        % hole Matlab Metadaten aus measurement_settings
        notizenValue = measurement_settings.AdditionalNotes{i};
        einheitValue = measurement_settings.CalculatedUnit{i};
        measuredQuantityValue = measurement_settings.MeasuredQuantity{i};
        messrichtungValue = measurement_settings.Direction{i};
        correspondingFieldName = measurement_settings.ChannelNameOrdered{i};
        % Tags für Matlab-Metadaten,Teil 1 von Line Protocol
        tags = [ measurementName, ',', chosenTagMatlab, ...
                 ',notizen=', char(notizenValue), ...
                 ',einheit=', char(einheitValue), ...
                 ',sampleRate=', num2str(sampleRate), ...
                 ',measuredQuantity=', char(measuredQuantityValue), ...
                 ',messrichtung=', char(messrichtungValue) ];
        % Field: correspondingFieldName
        fields = ['correspondingDataFieldName="', char(correspondingFieldName), '"'];
        
        matlabLines{i} = [ tags, ' ', fields, ' ', num2str(timestamp) ];
    end
    
    % 3) Edge-Metadaten-Zeilen erstellen
    chosenTagEdge = char(writeTagSyncedEdgeMetaData);
    % Für Edge: von Index numActiveChannels bis zum Ende der VariableNames
    startEdgeIdx = numActiveChannels;
    totalFields = numel(dataTable.Properties.VariableNames);
    numEdgeLines = totalFields - startEdgeIdx;
    edgeLines = cell(numEdgeLines, 1);
    
    % Fortlaufender Timestamp: Start direkt nach den Matlab-Daten
    lastMatlabTimestamp = int64(timestamp_base + (numMatlabLines-1)*timestamp_increment);
    timestamp_edge_base = lastMatlabTimestamp + timestamp_increment;
    
    % ersetze leere Zellen bei Einheit mit '1'
    emptyIdx = cellfun(@isempty, additionalMetadata.EdgeVariableUnits_rightOrder);
    additionalMetadata.EdgeVariableUnits_rightOrder(emptyIdx) = {'1'};


    for j = 1:numEdgeLines
        i_edge = j;
        timestamp = int64(timestamp_edge_base + (j-1)*timestamp_increment);
        
        % einheit: 
        if ~isempty(additionalMetadata.EdgeVariableUnits_rightOrder)
            einheitValue = additionalMetadata.EdgeVariableUnits_rightOrder{i_edge};
        else
            einheitValue = 'none';
        end
       
        % Tags für Edge-Metadaten: Hier werden notizen und einheit als Tags hinzugefügt
        tags = [ measurementName, ',', chosenTagEdge, ...
                 ',sampleRate=', num2str(sampleRate), ...
                 ',einheit=', char(einheitValue) ];
        
        % correspondingFieldName als Field 
        correspondingFieldName = dataTable.Properties.VariableNames{i_edge};
        %Field String erstellen
        fields = ['correspondingFieldName="', char(correspondingFieldName), '"'];
        
        edgeLines{j} = [ tags, ' ', fields, ' ', num2str(timestamp) ];
    end
    
    % 4) Kombiniere Matlab- und Edge-Zeilen und erstelle das Batch
    allLines = [matlabLines; edgeLines];
    writeBatch = strjoin(allLines, '\n');
    
    disp('Erzeugtes Line Protocol für Matlab- und Edge-Metadaten:');
    disp(writeBatch);
    
    % 5) Sende das Batch an InfluxDB
    statusMessage = sendLineProtocolToInflux(token, writeBucketName, orgIDName, writeBatch);
end


%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Funktionen von Florian Oexle
% Wichtig: Synchronisierungssignal läuft immer auf Channel 0!

function messdaten_syncr = SyncMatlabEdgeData(tmp, TT)
tmp_new = tmp;  % Zuteilung am Anfang, da tmp_new oft verwendet und Code nachtäglich geändert wurde, sensitivität wird nicht mehr hier berechnet, sondern ist sie schon!

clearvars -except timezoneCorrection timezoneCorrection writeTagSyncedMatlabMetaData writeTagSyncedEdgeMetaData additionalMetadata TT tmp_new measurement_settings measurementName writeBucketName orgIDName token sendBatchSize writeTagSyncedData additionalMetadata sampleRate_Edge sampleRate_Matlab % Workspace freiräumen

% Synchronisieren der Messungen
% Zuschneiden der Messungen: Beginne die Daten ab dem
% Zeitpunkt, ab dem der Wert der Edge auf 1 springt.

% Zuschneiden der Daten aus Data Translation: 
startIndex_tmp_new = getStartIndexOfTrigger(tmp_new,0.1,0.2);
fs = tmp_new.Properties.SampleRate; % Abtastrate der Data Translation bestimmen
startIndex_tmp_new = startIndex_tmp_new-0.5*fs;
tmp_new = tmp_new(startIndex_tmp_new:end,:);


% Zuschneiden der Daten aus der Edge:
test = find(TT.sync_signal == 0);
startIndexTT = test(end)+1;
fs_TT = TT.Properties.SampleRate; % Abtastrate der Data Translation bestimmen
startIndexTT = startIndexTT-0.5*fs_TT;
TT = TT(startIndexTT:end,:);

clearvars -except timezoneCorrection writeTagSyncedMatlabMetaData writeTagSyncedEdgeMetaData additionalMetadata TT tmp_new measurement_settings measurementName writeBucketName orgIDName token sendBatchSize writeTagSyncedData additionalMetadata sampleRate_Edge sampleRate_Matlab % Workspace freiräumen

% Abtastrate der Messungen der Edge erhöhen auf die Abtastrate der Data Translation Messkarte 
% mit linearer Interpolation
fs = tmp_new.Properties.SampleRate; % Abtastrate der Data Translation bestimmen
newTime = TT.Time(1):seconds(1/fs):TT.Time(end);  % Neuen Zeitvektor bestimmen, auf den die Messdaten der Edge gesampelt werden sollen 
TT = retime(TT, newTime, 'linear');    % Abtastrate anpassen

clearvars -except timezoneCorrection writeTagSyncedMatlabMetaData writeTagSyncedEdgeMetaData TT additionalMetadata tmp_new measurement_settings measurementName writeBucketName orgIDName token sendBatchSize writeTagSyncedData additionalMetadata sampleRate_Edge sampleRate_Matlab % Workspace freiräumen

% Kürzen der Zeitreihen, sodass diese gleich lang werden:
sizetmp_newData = size(tmp_new,1);
sizeTT = size(TT,1);
zuschnitt = min(sizetmp_newData,sizeTT);

% Zuschneiden der Daten aus Data Translation: 
tmp_new = tmp_new(1:zuschnitt,:);
% Zuschneiden der Daten aus der Edge:
TT = TT(1:zuschnitt,:);

clearvars -except timezoneCorrection writeTagSyncedMatlabMetaData writeTagSyncedEdgeMetaData tmp_new TT additionalMetadata measurement_settings measurementName writeBucketName orgIDName token sendBatchSize writeTagSyncedData additionalMetadata sampleRate_Edge sampleRate_Matlab % Workspace freiräumen

% Daten zusammenführen
% Zuerst die Werte der Data Translation und der Edge speichern
tmp_new_Table = timetable2table(tmp_new, 'ConvertRowTimes', false);
TT_Table = timetable2table(TT, 'ConvertRowTimes', false);

% Nun führe die Messdaten zu einer Tabelle zusammen
messdaten = horzcat(tmp_new_Table, TT_Table);

% Mache eine Timetable, die bei 0 sec beginnt
messdaten_syncr = table2timetable(messdaten,'SampleRate',tmp_new.Properties.SampleRate);

clearvars -except timezoneCorrection writeTagSyncedMatlabMetaData writeTagSyncedEdgeMetaData messdaten_syncr additionalMetadata measurement_settings measurementName writeBucketName orgIDName token sendBatchSize writeTagSyncedData additionalMetadata sampleRate_Edge sampleRate_Matlab % Workspace freiräumen

end

function startIndex = getStartIndexOfTrigger(table,tolerance,Tconsecutive)
%GETSTARTTIMETRIGGER Bestimmt den Index der eingegebenen Tabelle 'table',
%ab der im Edge-Signal, der Trigger von 0 auf 1 springt. Die Tabelle
%'table' enthält Messsignale, die mit der Messkarte Data-Translation
%aufgenommen wurden. Der in dieser Funktion ermittelte startIndex kann
%verwendet werden, um die Signale aus der Edge mit denen der
%Data-Translation zu matchen.
%   INPUT ARGUMENTS
%   - table         Eine Tabelle, die die 'Taktgeber' Spalte enthält und
%                   die Werte des Taktgebersignals enthält.
%   - tolerance     Toleranz, um den die Werte von 'Taktgeber' schwanken
%                   dürfen. Wird benötigt, um herauszufinden, wann ein
%                   annähernd konstanter Wert in 'Taktgeber' gehalten wird.
%   - Tconsecutive  Gibt die Zeit an (in Sekunden), über die der konstante
%                   Wert in 'Taktgeber' mindestens gehalten wird, bevor das
%                   Signal wieder auf null bzw. eins fällt.
%
%   OUTPUT ARGUMENTS
%   startIndex      Index, der Tabelle 'table', ab der das Trigger-Signal im
%                   Edge-Signal auf 1 fällt.

% Abtastrate der Tabelle 'table' bestimmen
fs = table.Properties.SampleRate;

% Berechne die Zeilenanzahl, über die der konstante
% Wert in 'Taktgeber' mindestens gehalten wird, bevor das
% Signal wieder auf null bzw. eins fällt.
consecutive = round(Tconsecutive*fs); 

deltas = abs(diff(table.Sync_Signal));  % Berechnet die Differenz zwischen aufeinanderfolgenden Werten des 'Taktgeber' und nimmt den Betrag davon.
test = deltas <= tolerance;           % Erstellt einen booleschen Vektor test, der anzeigt, ob die Differenzen kleiner oder gleich der Toleranz sind.
%disp(table.Taktgeber);
% Im folgenden wird nach einer Sequenz von consecutive aufeinanderfolgenden
% true-Werten im Vektor test gesucht.
j = find(conv(double(test), ones(consecutive, 1), 'valid') == consecutive, 1);

% Findet die ersten Indizes im Bereich von j bis j+2*fs, an denen der Wert false ist.
j_2 = find(test(j:end) == 0);

% Addiere auf j_2 wieder j, da bei der Bestimmung von j_2 ab Index j in
% 'test' gesucht wurde.
if isempty(j_2)
    disp('Fehler');
end
startIndex = j_2(1,1)+j;
end

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
