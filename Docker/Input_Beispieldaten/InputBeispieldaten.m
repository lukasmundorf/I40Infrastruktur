%% Skript, um manuell Daten in die Influx einzuschreiben, da die Verbindung nicht funktionieren wird

% Testargumente für hier entfernen, sobald in Microservice umgewandelt wird
measurementName = "realData08"; 
writeBucketName = "daten-roh";
orgIDName = "4c0bacdd5f5d7868";
sendBatchSize = 5000;
token = 'R-Klt0c_MSuLlVJwvDRWItqX40G_ATERJvr4uy93xgYe1d7MoyHIY_sc_twi4h6GnQdmU9WJI74NbwntEI2luw==';
writeEdgeDataTag = 'dataType=edgeData';
writeMatlabDataTag = 'dataType=matlabData';
writeMatlabMetadataTag = 'dataType=matlabMetadata';
%% laden von Testdaten
edgeDataUnsynced = load('EdgeDaten.mat');
disp('Edge-Daten geladen');

matlabDataUnsynced_withMeasurementSettings = load('MatlabDaten.mat');
disp('Matlab-Daten geladen');
matlabDataUnsynced = rmfield(matlabDataUnsynced_withMeasurementSettings, 'measurement_settings');


% Senden von Edge-Daten an InfluxDB
statusMessage1 = convertAndSendTable(measurementName, writeBucketName, orgIDName, token, sendBatchSize, writeEdgeDataTag, edgeDataUnsynced);

% Senden von Edge-Daten an InfluxDB
statusMessage2 = convertAndSendTable(measurementName, writeBucketName, orgIDName, token, sendBatchSize, writeMatlabDataTag, matlabDataUnsynced);

statusMessage3 = sendExampleMetadata(measurementName, writeBucketName, orgIDName, token);



%% Funktion zur Konvertierung von zusammengefasster synchronisierter Tabelle und Schreiben in InfluxDB in Batches

function statusMessage = convertAndSendTable(measurementName, writeBucketName, orgIDName, token, batchSize, writeTag, matlabDataUnsynced)
    % Finde den Tabellen-Namen innerhalb des Objekts
    tableNames = fieldnames(matlabDataUnsynced);
    if isempty(tableNames)
        error('Das Objekt DataTableUnsynced enthält keine Tabelle.');
    end
    tableName = tableNames{1}; % Erste Tabelle auswählen

    % Extrahiere die eigentliche Tabelle
    dataTable = matlabDataUnsynced.(tableName);
    
    % Hole die Spaltennamen
    columnNames = dataTable.Properties.VariableNames;
    % Ersetze nur die Spalten, die exakt dem Muster "DT9836(00)_<Zahl>" entsprechen
    for i = 1:length(columnNames)
        if ~isempty(regexp(columnNames{i}, '^DT9836\(00\)_\d+$', 'once'))
            columnNames{i} = regexprep(columnNames{i}, '^DT9836\(00\)_(\d+)$', 'voltage$1');
        end
    end
    % Aktualisiere die Spaltennamen in der Tabelle
    dataTable.Properties.VariableNames = columnNames;
    
    % Konfiguration der Zeitstempel
    % Aktuelle Zeit in Nanosekunden abrufen (-1h für richtige Zeitzone)
    unixNowNs = posixtime(datetime('now')) * 1e9 - (3600 * 1e9);
    
    % SampleRate aus den Tabelleneigenschaften
    sampleRate = dataTable.Properties.SampleRate;
    timeStepNs = 1e9 / sampleRate; % Zeitinkrement pro Zeile in Nanosekunden
    
    % Anzahl der Zeilen bestimmen
    [numRows, ~] = size(dataTable);

    % Anzahl der Batches berechnen
    numBatches = ceil(numRows / batchSize);

    % Berechne alle Zeitstempel VEKTORISIERT
    timestampsNs = int64(unixNowNs + (0:numRows-1)' * timeStepNs);

    % Starte den Timer für die Zeitabschätzung
    overallTimer = tic;
    
    % Erzeuge und sende Line Protocol in Batches
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
%   token           - InfluxDB-Token (String)
%   writeBucketName - Name des Buckets, in den geschrieben werden soll (String)
%   orgIDName       - Name bzw. ID der Organisation (String)
%   writeBatch      - Payload im Line Protocol (String)
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
        disp(response);
        statusMessage = 'Write abgeschlossen';
    catch ME
        fprintf('Fehler: %s\n', ME.message);
        statusMessage = 'Fehler';
    end
end

function statusMessage2 = sendExampleMetadata(measurementName, writeBucketName, orgIDName, token)
    % Stelle sicher, dass measurementName ein Character Vector ist und ersetze Leerzeichen
    measurementName = char(measurementName);
    measurementName = strrep(measurementName, ' ', '_');
    if isempty(measurementName)
        measurementName = 'none';
    end
    
    % Erstelle ein Cell-Array für 12 Zeilen
    lines = cell(12, 1);

    % Definiere die Werte für die bisherigen Tags
    einheitValues = {'/', 'V/mcm', 'V/mcm', 'V/mcm', 'V/mcm', 'V/mcm', 'N/V', 'N/V', 'N/V', 'mV/g_n', 'mV/g_n', 'mV/g_n'};
    measuredQuantityValues = {'Sync_Signal', 'Displacement', 'Displacement', 'Displacement', 'Displacement', 'Displacement', 'Force', 'Force', 'Force', 'Acceleration', 'Acceleration', 'Acceleration'};
    messrichtungValues = {'', '+Z', '-X', '+Z', '-Y', '+Z', '+X', '-Y', '+Z', '-Z', '+Y', '+X'};
    notizenValues = {'Edge Daten', 'Capacity + X-Axis Flat', 'Capacity - X-Axis Round', 'Capacity + 45°-Axis Flat', 'Capacity - Y-Axis Round', 'Capacity + Y-Axis Flat', 'Stationary Dynamometer + X', 'Stationary Dynamometer - Y', 'Stationary Dynamometer + Z', 'Accelerometer - Z-Axis', 'Accelerometer + Y-Axis', 'Accelerometer + X-Axis'};

    % Ersetze in notizenValues alle Leerzeichen durch Unterstriche
    for i = 1:length(notizenValues)
        notizenValues{i} = strrep(notizenValues{i}, ' ', '_');
    end

    % Für alle Tag-Arrays: falls ein Element leer ist, setze es auf "none"
    arrays = {einheitValues, measuredQuantityValues, messrichtungValues, notizenValues};
    for a = 1:length(arrays)
        for i = 1:length(arrays{a})
            if isempty(arrays{a}{i}) || strcmp(arrays{a}{i}, '')
                arrays{a}{i} = 'none';
            end
        end
    end
    % Übernehme die geänderten Arrays zurück
    einheitValues = arrays{1};
    measuredQuantityValues = arrays{2};
    messrichtungValues = arrays{3};
    notizenValues = arrays{4};

    % Konstanten
    sampleRate = 10000;
    topic = 'test/topic';
    host = 'fa93992c4aa5';
    
    % Auch für topic und host: falls leer, setze "none"
    if isempty(topic) || strcmp(topic, '')
        topic = 'none';
    end
    if isempty(host) || strcmp(host, '')
        host = 'none';
    end

    % Definiere die Werte für den Tag "sensitivity"
    sensitivityValues = {0, 0.00200000000000000, 0.00200000000000000, 0.00200000000000000, 0.00200000000000000, 0.00200000000000000, 500, 500, 200, 10.3100000000000, 10.2300000000000, 10.5000000000000};

    % Definiere die Field-Werte für ChannelName von ch0 bis ch11
    channelValues = {'ch0','ch1','ch2','ch3','ch4','ch5','ch6','ch7','ch8','ch9','ch10','ch11'};
    for i = 1:length(channelValues)
        if isempty(channelValues{i}) || strcmp(channelValues{i}, '')
            channelValues{i} = 'none';
        end
    end

    % Berechne den Basis-Zeitstempel in ns (aktuelle Unix-Zeit in ns minus 3600*10^9)
    timestamp_base = posixtime(datetime('now')) * 1e9 - 3600*1e9;
    % Setze das Inkrement auf 0,1ms = 1e5 ns
    timestamp_increment = 1e5; 

    % Fülle jede Zeile mit den bisher gesetzten Tags, dem Field-Paar und dem Zeitstempel
    for i = 1:12
        % Zeitstempel: Jede Zeile timestamp_increment ns später als die vorherige
        timestamp = int64(timestamp_base + (i-1) * timestamp_increment);
        
        % Zusammenbauen der Zeile im Influx Line Protocol Format:
        % measurement,<tags> <fields> <timestamp>
        lines{i} = [measurementName, ...
            ',dataType=metadata', ...
            ',einheit=', einheitValues{i}, ...
            ',measuredQuantity=', measuredQuantityValues{i}, ...
            ',messrichtung=', messrichtungValues{i}, ...
            ',notizen=', notizenValues{i}, ...
            ',sampleRate=', num2str(sampleRate), ...
            ',sensitivity=', num2str(sensitivityValues{i}), ...
            ',topic=', topic, ...
            ',host=', host, ...
            ' ChannelName="', channelValues{i}, '" ', ...
            num2str(timestamp)];
    end

    % Verbinde alle Zeilen mit einem Zeilenumbruch
    writeBatch = strjoin(lines, '\n');
    disp(writeBatch);
    statusMessage2 = sendLineProtocolToInflux(token, writeBucketName, orgIDName, writeBatch);
end
