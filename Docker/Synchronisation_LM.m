%{
1. Daten formatieren
Vorgehen:

1.1 Matlab Daten
    Was wird gebraucht um Tabelle richtig zu formatieren?
        --- 1. Metadaten => abgepackt in 1x1 Struct (name: measurement_settings) mit 6 Fields ---
                Samplerate      => Zahlenwert => abspeichern in "xxx".Properties.SampleRate
                MeasuredQuantitiy (was messe ich da eigentlich?) => 1x12 String
                Direction =>  1x12 String
                SensitivityValue =>  1x12 double
                SensitivityUnit  =>  1x12 String
                Additional Notes =>  1x12 String
        --- 2. Metadaten in timetable.Properties ---
                VariableUnits => extrahieren aus MeasuredQuantity
                SampleRate => Extrahieren aus Samplerate
        --- 3. Datenpunkte: Timetable Tabelle mit einzelnen Datenpunkten als eigene Einträge ---
            Spalten: Channels
            Zeilen Zeitstempel => einfach erstellen mit SampleRate
    Wie machen? 
        1. keine Ahnung man, woher soll ich das denn wissen
        2. influx über HTTP die gesamte Messung Querrien => jeder einzelne Datenpunkt ist eine Zeile, siehe Testdatensätze
        3. Umwandlung der QueryTabelle in brauchbare Tabelle

%}

% Beispielcode zum Erstellen eines measurement_settings-Structs



measurement_settings = getStructuredMetadata();

%matlabQueryData = getMatlabData();


%% Funktionen

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

    %% 5) MeasuredQuantity (1xN String)
    if ismember('measurementQuantity', metadataTabelle.Properties.VariableNames)
        metadataStruct.MeasuredQuantity = string(metadataTabelle.measurementQuantity)';
    else
        metadataStruct.MeasuredQuantity = strings(1, anzahlChannels);
    end

    %% 6) Direction (1xN String)
    if ismember('messrichtung', metadataTabelle.Properties.VariableNames)
        metadataStruct.Direction = string(metadataTabelle.messrichtung)';
    else
        metadataStruct.Direction = strings(1, anzahlChannels);
    end

    %% 7) SensitivityValue (1xN double)
    if ismember('sensitivity', metadataTabelle.Properties.VariableNames)
        if iscell(metadataTabelle.sensitivity)
            metadataStruct.SensitivityValue = cell2mat(metadataTabelle.sensitivity)';
        else
            metadataStruct.SensitivityValue = metadataTabelle.sensitivity';
        end
    else
        metadataStruct.SensitivityValue = nan(1, anzahlChannels);
    end

    %% 8) SensitivityUnit (1xN String)
    if ismember('einheit', metadataTabelle.Properties.VariableNames)
        metadataStruct.SensitivityUnit = string(metadataTabelle.einheit)';
    else
        metadataStruct.SensitivityUnit = strings(1, anzahlChannels);
    end

    %% 9) Additional Notes (1xN String)
    if ismember('notizen', metadataTabelle.Properties.VariableNames)
        metadataStruct.AdditionalNotes = string(metadataTabelle.notizen)';
    else
        metadataStruct.AdditionalNotes = strings(1, anzahlChannels);
    end

    %% 10) SampleRate (Zahlenwert)
    if ismember('sampleRate', metadataTabelle.Properties.VariableNames)
        % Verwenden Sie den ersten Eintrag der Spalte
        metadataStruct.SampleRate = metadataTabelle.sampleRate(1);
    else
        metadataStruct.SampleRate = [];
    end
end

function metaData = getMetadata()
% Lädt die Metadaten aus der Datei 'InfluxMatlabMetaDataQuery.mat'
    metaData = load('InfluxMatlabMetaDataQuery.mat');
end

function matlabData = getMatlabData()
% Lädt die Matlab-Daten aus der Datei 'InfluxMatlabDataQuery.mat'
    matlabData = load('InfluxMatlabDataQuery.mat');
end
