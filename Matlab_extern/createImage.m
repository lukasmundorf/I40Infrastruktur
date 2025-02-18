% result = compiler.build.productionServerArchive('httpToMqtt.m', 'ArchiveName','http_to_mqtt','Verbose','on');
% compiler.package.microserviceDockerImage(result,'ImageName','http-to-mqtt')


% matlabFileName = "httpToMqtt.m";
% archiveName = "http_to_mqtt";
% imageName = "http-to-mqtt";


matlabFileName = 'matlab_request.m';
archiveName = 'matlab_request';
imageName = 'matlab-request';



result = compiler.build.productionServerArchive(matlabFileName, 'ArchiveName',archiveName,'Verbose','on');
compiler.package.microserviceDockerImage(result,'ImageName',imageName)

