% Beispiel-Daten erstellen
x = [1, 2, 3];
y = 42;
z = 'Beispieltext';
A = magic(3);

% Zielordner (falls noch nicht vorhanden)
if ~exist('input', 'dir')
    mkdir('input');
end

% Speichern in .mat-Datei
save('input/data.mat', 'x', 'y', 'z', 'A');