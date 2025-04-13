% result = compiler.build.productionServerArchive('httpToMqtt.m', 'ArchiveName','http_to_mqtt','Verbose','on');
% compiler.package.microserviceDockerImage(result,'ImageName','http-to-mqtt')


% matlabFileName = "httpToMqtt.m";
% archiveName = "http_to_mqtt";
% imageName = "http-to-mqtt";


% matlabFileName = 'matlab_request.m';
% archiveName = 'matlab_request';
% imageName = 'matlab-request';

% matlabFileName = "myMicroservice.m";
% archiveName = "my_Microservice";
% imageName = "test-conversion";

matlabFileName = "SynchronizeMatlabEdgeDataDockerContainer.m";
archiveName = "synchronize_matlab_edge_data";
imageName = "synchronize-matlab-edge-data";


% matlabFileName = "timestampDockerVsScript.m";
% archiveName = "timestamp_DockerVsScript";
% imageName = "timestamp-docker-vs-script";



result = compiler.build.productionServerArchive(matlabFileName, 'ArchiveName',archiveName,'Verbose','on');
compiler.package.microserviceDockerImage(result,'ImageName',imageName)

