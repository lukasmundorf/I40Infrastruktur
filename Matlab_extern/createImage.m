clearvars
clc

result = compiler.build.productionServerArchive('arrayToString_03.m', 'ArchiveName','array_to_string_03','Verbose','on');
compiler.package.microserviceDockerImage(result,'ImageName',['array-to-string_03'])





% result = compiler.build.productionServerArchive('arrayToString.m', 'ArchiveName','array_to_string','Verbose','on');
% compiler.package.microserviceDockerImage(result,'ImageName','array-to-string')


% result = compiler.build.productionServerArchive('httpToMqtt.m', 'ArchiveName','http_to_mqtt','Verbose','on');
% compiler.package.microserviceDockerImage(result,'ImageName','http-to-mqtt')