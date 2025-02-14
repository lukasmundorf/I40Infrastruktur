clearvars
clc

result = compiler.build.productionServerArchive('arrayToString_06.m', 'ArchiveName','array_to_string_06','Verbose','on');
compiler.package.microserviceDockerImage(result,'ImageName',['array-to-string_06'])





% result = compiler.build.productionServerArchive('arrayToString.m', 'ArchiveName','array_to_string','Verbose','on');
% compiler.package.microserviceDockerImage(result,'ImageName','array-to-string')


% result = compiler.build.productionServerArchive('httpToMqtt.m', 'ArchiveName','http_to_mqtt','Verbose','on');
% compiler.package.microserviceDockerImage(result,'ImageName','http-to-mqtt')