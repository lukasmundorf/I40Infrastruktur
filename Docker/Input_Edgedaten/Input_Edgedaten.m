%% Skript, um manuell Edge Daten in die Influx einzuschreiben, da die Verbindung nicht funktionieren wird

% Testargumente für hier entfernen, sobald in Microservice umgewandelt wird
measurementName = "realData02"; 
writeBucketName = "daten-roh";
orgIDName = "4c0bacdd5f5d7868";
sendBatchSize = 5000;
token = 'R-Klt0c_MSuLlVJwvDRWItqX40G_ATERJvr4uy93xgYe1d7MoyHIY_sc_twi4h6GnQdmU9WJI74NbwntEI2luw==';
writeTag = 'dataType=edgeData';

%% laden von Testdaten
finishedTableSynced = load('EdgeDaten.mat');
disp('Daten geladen')

%senden von Daten an InfluxDB
statusMessage = convertAndSendTable(measurementName, writeBucketName, orgIDName, token, sendBatchSize, writeTag, finishedTableSynced);


%% Funktion zur Konvertierung von zusammengefasster synchronisierter Tabelle und Schreiben in InfluxDB in Batches

function statusMessage = convertAndSendTable(measurementName, writeBucketName, orgIDName, token, batchSize, writeTag, finishedTableSynced)
    % Finde den Tabellen-Namen innerhalb des Objekts
    tableNames = fieldnames(finishedTableSynced);
    if isempty(tableNames)
        error('Das Objekt finishedTableSynced enthält keine Tabelle.');
    end
    tableName = tableNames{1}; % Erste Tabelle auswählen

    % Extrahiere die eigentliche Tabelle
    dataTable = finishedTableSynced.(tableName);
    
    %% Konfiguration der Zeitstempel
    % Aktuelle Zeit in Nanosekunden abrufen (-1h für richtige Zeitzone)
    unixNowNs = posixtime(datetime('now')) * 1e9 - (3600 * 1e9);
    
    % SampleRate aus den Tabelleneigenschaften
    sampleRate = dataTable.Properties.SampleRate;
    timeStepNs = 1e9 / sampleRate; % Zeitinkrement pro Zeile in Nanosekunden
    
    % Anzahl der Zeilen und Spalten bestimmen
    [numRows, ~] = size(dataTable);
    columnNames = dataTable.Properties.VariableNames; % Spaltennamen als Field-Namen

    % Anzahl der Batches berechnen
    numBatches = ceil(numRows / batchSize);

    % Berechne alle Zeitstempel VEKTORISIERT
    timestampsNs = int64(unixNowNs + (0:numRows-1)' * timeStepNs);

    %% Starte den Timer für die Zeitabschätzung
    overallTimer = tic;
    
    %% Erzeuge und sende Line Protocol in Batches
    for batchIdx = 1:numBatches
        % Start- und Endindex für diesen Batch
        startIdx = (batchIdx - 1) * batchSize + 1;
        endIdx = min(batchIdx * batchSize, numRows);
        batchTimestamps = timestampsNs(startIdx:endIdx);

        % Extrahiere den relevanten Datenbereich als Matrix
        batchData = dataTable{startIdx:endIdx, :};

        % Konvertiere die Daten in einen formatierbaren String
        batchDataStr = string(batchData);
        batchFields = columnNames + "=" + batchDataStr;
        batchFieldsStr = join(batchFields, ",", 2);
        
        % Erstelle das Line Protocol für diesen Batch:
        % Format: measurementName,tagKey=tagValue field1=value1,field2=value2 ... timestamp
        lineProtocol = measurementName + "," + writeTag + " " + batchFieldsStr + " " + string(batchTimestamps);
        
        % Kombiniere alle Zeilen zu einem einzigen String
        writeBatch = join(lineProtocol, newline);

        % Daten senden
        statusMessage = sendLineProtocolToInflux(token, writeBucketName, orgIDName, writeBatch);

        % Berechne verstrichene Zeit und geschätzte verbleibende Zeit (in Sekunden)
        elapsedTime = toc(overallTimer);
        avgTimePerBatch = elapsedTime / batchIdx;
        remainingBatches = numBatches - batchIdx;
        estimatedRemainingTime = avgTimePerBatch * remainingBatches;
        
        % Umrechnung in Stunden, Minuten und Sekunden
        hours = floor(estimatedRemainingTime / 3600);
        minutes = floor(mod(estimatedRemainingTime, 3600) / 60);
        seconds = mod(estimatedRemainingTime, 60);

        % Log-Ausgabe: Batch-Info und geschätzte verbleibende Zeit
        if strcmp(statusMessage, 'Write abgeschlossen')
            fprintf('Batch %d/%d mit %d Zeilen gesendet. Geschätzte verbleibende Zeit: %d h %d m %.0f s.\n', ...
                batchIdx, numBatches, endIdx - startIdx + 1, hours, minutes, seconds);
        else
            disp(statusMessage)
        end

    end
end



%% Funktion, um Line Protocol in die Influx zu schreiben

function statusMessage = sendLineProtocolToInflux(token, writeBucketName, orgIDName, writeBatch)
% sendLineProtocolToInflux sendet Daten im Line Protocol an InfluxDB.
%
%   statusMessage = sendLineProtocolToInflux(token, writeBucketName, orgIDName, writeBatch)
%
%   token         - InfluxDB-Token (String)
%   writeBucketName - Name des Buckets, in den geschrieben werden soll (String)
%   orgIDName     - Name bzw. ID der Organisation (String)
%   writeBatch    - Payload im Line Protocol (String)
%
%   Beispiel für writeBatch:
%       writeBatch = sprintf(['measurement value=0 %0.0f\n' ...
%                             'measurement value=1 %0.0f\n' ...
%                             'measurement value=2 %0.0f'], ...
%                             nowNs, nowNs+1e9, nowNs+2e9);

    % InfluxDB-URL mit Bucket, Organisation und Nanosekunden-Precision
    influxURL = sprintf('http://localhost:8086/api/v2/write?org=%s&bucket=%s&precision=ns', orgIDName, writeBucketName);

    % Weboptions konfigurieren
    options = weboptions(...
        'RequestMethod', 'post', ...
        'MediaType', 'text/plain', ...
        'HeaderFields', {...
            'Authorization', ['Token ' token]; ...
            'Content-Type', 'text/plain; charset=utf-8'} ...
        );

    % Anfrage senden
    try
        fprintf('Sende Write-Anfrage an InfluxDB...\n');
        response = webwrite(influxURL, writeBatch, options);
        %fprintf('Write erfolgreich');
        disp(response);
        statusMessage = 'Write abgeschlossen';
    catch ME
        %fprintf('Fehler bei der Anfrage: %s\n', ME.message);
        statusMessage = sprintf('Fehler: %s', ME.message);
    end
end
