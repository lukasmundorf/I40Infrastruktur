function doubleValues()
% doubleValues verdoppelt alle numerischen Felder in 'input/data.mat'
% und speichert sie als 'output/data_double.mat'.

    % Feste Eingabe- und Ausgabepfade
    inputFile = '/mnt/shared/input/data.mat';
    outputFile = '/mnt/shared/output/data_double.mat';

    % Datei laden
    data = load(inputFile);

    % Alle Felder durchgehen
    fields = fieldnames(data);
    for i = 1:numel(fields)
        val = data.(fields{i});
        if isnumeric(val)
            data.(fields{i}) = 2 * val;
        end
    end

    % Zielordner erstellen, falls nicht vorhanden
    outputDir = fileparts(outputFile);
    if ~isempty(outputDir) && ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    % Neue Datei speichern
    save(outputFile, '-struct', 'data');
end