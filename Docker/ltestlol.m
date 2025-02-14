% Beispielhafte Strings
str1 = 'Hallo'; str2 = 'dies'; str3 = 'ist'; str4 = 'ein'; str5 = 'Test';
str6 = 'mit'; str7 = 'vielen'; str8 = 'Strings'; str9 = 'in'; str10 = 'einer';
str11 = 'Funktion'; str12 = 'die'; str13 = 'alles'; str14 = 'zusammenfügt';
str15 = 'und'; str16 = 'am'; str17 = 'Ende'; str18 = 'noch'; str19 = 'eine';
str20 = 'Zahl'; str21 = 'und'; str22 = 'ein'; str23 = 'Array'; str24 = 'anhängt';
str25 = 'damit'; str26 = 'wir'; str27 = 'sehen'; str28 = 'ob'; str29 = 'es';
str30 = 'funktioniert'; str31 = 'oder'; str32 = 'nicht'; str33 = 'und';
str34 = 'ob'; str35 = 'alles'; str36 = 'korrekt'; str37 = 'ist';

% Beispielhafte Zahlenwerte
numArray = [1.2, 3.4, 5.6, 7.8];
num = 42;

% Funktionsaufruf
output = arrayToString_07(str1, str2, str3, str4, str5, str6, str7, str8, str9, str10, ...
    str11, str12, str13, str14, str15, str16, str17, str18, str19, str20, ...
    str21, str22, str23, str24, str25, str26, str27, str28, str29, str30, ...
    str31, str32, str33, str34, str35, str36, str37, numArray, num);

% Ergebnis ausgeben
disp(output);