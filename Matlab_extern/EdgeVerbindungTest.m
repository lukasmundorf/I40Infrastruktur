mqttClient = mqttclient("tcp://localhost:9883", ClientID="mqttx_017e530e", Username="DMCMaschine", Password="DMCMaschine");
%mqttClient = mqttclient("mqtt://172.22.168.64", ClientID="mqttx_017e530e",Port = 9883, Username="edge", Password="edge");

disp(mqttClient.Connected);
topic = "test/control";    % Für Steuerbefehle
