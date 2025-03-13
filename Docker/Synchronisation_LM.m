

measurement_settings = getStructuredMetadata(); % Vorbereitung Metadaten
StructuredMatlabData = getStructuredMatlabData(measurement_settings); % Vorbereitung Messdaten

%% Funktion, um Metadaten aus Influx zu holen und richtig zu sortieren, sodass Synchronisation starten kann

function metadataStruct = getStructuredMetadata()
% getStructuredMetadata - Lädt die Metadaten und formatiert sie in ein Struct.
%
% Es werden Daten aus der MAT-Datei 'InfluxMatlabMetaDataQuery.mat' geladen.
% Aus der darin enthaltenen Tabelle wird ein Struct erstellt mit den Feldern:
%   - MeasuredQuantity    (1xN String)
%   - Direction           (1xN String)
%   - SensitivityValue    (1xN double)
%   - SensitivityUnit     (1xN String)
%   - AdditionalNotes     (1xN String)
%   - SampleRate          (Zahlenwert, aus der Spalte "sampleRate")
%
% Beispielaufruf:
%   >> measurement_settings = getStructuredMetadata();

    % 1) Tabelle laden (aus InfluxMatlabMetaDataQuery.mat)
    matlabQueryMetadata = getMetadata();

    % 2) Aus dem geladenen Struct die Tabelle extrahieren.
    feldNamen       = fieldnames(matlabQueryMetadata);
    metadataTabelle = matlabQueryMetadata.(feldNamen{1});

    % 3) Anzahl der Zeilen (Channels) bestimmen
    anzahlChannels = height(metadataTabelle);

    % 4) Internes Struct initialisieren
    metadataStruct = struct();

    % 5) MeasuredQuantity (1xN String)
    if ismember('measurementQuantity', metadataTabelle.Properties.VariableNames)
        metadataStruct.MeasuredQuantity = string(metadataTabelle.measurementQuantity)';
    else
        metadataStruct.MeasuredQuantity = strings(1, anzahlChannels);
    end

    % 6) Direction (1xN String)
    if ismember('messrichtung', metadataTabelle.Properties.VariableNames)
        metadataStruct.Direction = string(metadataTabelle.messrichtung)';
    else
        metadataStruct.Direction = strings(1, anzahlChannels);
    end

    % 7) SensitivityValue (1xN double)
    if ismember('sensitivity', metadataTabelle.Properties.VariableNames)
        if iscell(metadataTabelle.sensitivity)
            metadataStruct.SensitivityValue = cell2mat(metadataTabelle.sensitivity)';
        else
            metadataStruct.SensitivityValue = metadataTabelle.sensitivity';
        end
    else
        metadataStruct.SensitivityValue = nan(1, anzahlChannels);
    end

    % 8) SensitivityUnit (1xN String)
    if ismember('einheit', metadataTabelle.Properties.VariableNames)
        metadataStruct.SensitivityUnit = string(metadataTabelle.einheit)';
    else
        metadataStruct.SensitivityUnit = strings(1, anzahlChannels);
    end

    % 9) Additional Notes (1xN String)
    if ismember('notizen', metadataTabelle.Properties.VariableNames)
        metadataStruct.AdditionalNotes = string(metadataTabelle.notizen)';
    else
        metadataStruct.AdditionalNotes = strings(1, anzahlChannels);
    end

    % 10) SampleRate (Zahlenwert)
    if ismember('sampleRate', metadataTabelle.Properties.VariableNames)
        % Verwenden Sie den ersten Eintrag der Spalte
        metadataStruct.Samplerate = metadataTabelle.sampleRate(1);
    else
        metadataStruct.SampleRate = [];
    end
end

%% Funktion, um Daten aus Influx zu holen und richtig zu sortieren, sodass Synchronisation starten kann

function dataTT = getStructuredMatlabData(measurement_settings)
% getStructuredMatlabData - Formt die abgefragten Messdaten (x_field, x_value, x_time)
% zu einer Timetable um, in der die Spalten gemäß der Kanalnummer (0 bis 11)
% sortiert sind. Die Zeitachse wird anhand der in measurement_settings.Samplerate
% gespeicherten Abtastrate erstellt.
%
% Die Tabelle wird über getMatlabData() geladen und enthält typischerweise die Spalten:
%   - x_field: z.B. 'voltage0', 'voltage1', ... (Kanalkennung)
%   - x_value: Messwerte
%   - x_time : InfluxDB-Timestamps (werden hier nicht genutzt)
%
% Voraussetzungen:
%   - Die Query-Tabelle ist blockweise sortiert, d.h. die Daten eines Kanals
%     stehen hintereinander, allerdings in der Reihenfolge, in der sie aus Influx kommen.
%   - measurement_settings.Samplerate enthält die Abtastrate.
%
% Rückgabe:
%   dataTT: timetable mit einer Spalte pro Kanal in sortierter Reihenfolge.

    % 1) Große Tabelle laden (z. B. mehrere Mio. Zeilen)
    loadedStruct = getMatlabData();  % enthält u.a. x_field, x_value, x_time
    fieldNames = fieldnames(loadedStruct);
    dataTable = loadedStruct.(fieldNames{1});

    % 2) Ermitteln der eindeutigen Kanäle in der Reihenfolge, wie sie in der Tabelle vorkommen
    uniqueChannelsStable = unique(dataTable.x_field, 'stable');
    nUnique = numel(uniqueChannelsStable);
    
    % Bestimmen der Anzahl Samples pro Kanal (Annahme: alle Kanäle haben gleich viele Werte)
    nRows = height(dataTable);
    nSamples = nRows / nUnique;
    
    % 3) Die Blöcke (Werte pro Kanal) in einem Zellenarray ablegen, sortiert nach Kanalnummer
    % Wir gehen davon aus, dass die Kanalkennung das Format "voltage<number>" hat.
    % Wir legen die Daten in einem Array ab, in dem an Position channelNumber+1 die Werte
    % dieses Kanals stehen.
    maxChannel = -Inf;
    % Zunächst die Kanalnummern ermitteln, um die maximale Nummer zu bestimmen:
    channelNums = zeros(nUnique,1);
    for i = 1:nUnique
        chName = uniqueChannelsStable{i};
        numStr = regexp(chName, '\d+', 'match');
        if ~isempty(numStr)
            channelNums(i) = str2double(numStr{1});
        else
            channelNums(i) = NaN;
        end
        if channelNums(i) > maxChannel
            maxChannel = channelNums(i);
        end
    end
    % Legen Sie ein Zellenarray an, das mindestens (maxChannel+1) Plätze hat.
    sortedBlocks = cell(1, maxChannel+1);
    sortedNames  = cell(1, maxChannel+1);
    
    % Jetzt für jeden Kanalblock aus der Query:
    for i = 1:nUnique
        blockStart = (i-1)*nSamples + 1;
        blockEnd   = i*nSamples;
        blockData = dataTable.x_value(blockStart:blockEnd);
        
        chName = uniqueChannelsStable{i};
        numStr = regexp(chName, '\d+', 'match');
        if ~isempty(numStr)
            chNum = str2double(numStr{1});
        else
            chNum = NaN;
        end
        
        % Speichern in der Position chNum+1
        sortedBlocks{chNum+1} = blockData;
        sortedNames{chNum+1} = chName;  % Alternativ: sprintf('voltage%d', chNum)
    end
    
    % 4) Neue Zeitachse anhand der SampleRate erstellen
    Fs = measurement_settings.Samplerate;  % z. B. 1000 Hz
    dt = 1 / Fs;                         % Abtastintervall
    timeArray = seconds((0:nSamples-1)' * dt);
    
    % 5) Leere Timetable initialisieren
    dataTT = timetable(timeArray, 'VariableNames', {});
    
    % 6) Die sortierten Kanaldaten in die Timetable einfügen – von Kanal 0 bis maxChannel
    for ch = 0:maxChannel
        idx = ch + 1;
        if ~isempty(sortedBlocks{idx})
            % Verwenden Sie als Spaltennamen den originalen Namen (oder generieren Sie einen neuen)
            colName = sortedNames{idx};
            dataTT.(colName) = sortedBlocks{idx};
        end
    end
    
    % 7) Timetable-Eigenschaften setzen (optional)
    dataTT.Properties.SampleRate = Fs;
end

%% Funktion um Metadaten aus der Influx zu querien

function metaData = getMetadata()
% Lädt die Metadaten aus der Datei 'InfluxMatlabMetaDataQuery.mat'
    metaData = load('InfluxMatlabMetaDataQuery.mat');
end

%% Funktion um Messdaten aus der Influx zu querien

function matlabData = getMatlabData()
% Lädt die Matlab-Daten aus der Datei 'InfluxMatlabDataQuery.mat'
    matlabData = load('InfluxMatlabDataQuery_Short.mat');
end

%% Funktion um Testdaten, die nichts mit der Influx zu tun haben, zu holen (zur Validierung dass der Code das richtige macht) , kann anstatt von getMatlabData() ausgewählt werden

function matlabData = getMatlabValidationData()
% Lädt die Matlab-Daten aus der Datei 'InfluxMatlabDataQuery.mat'
    matlabData = load('ValidationTestQuery.mat');
end

%% Funktion zum richtiges Einspeisen in Influx

