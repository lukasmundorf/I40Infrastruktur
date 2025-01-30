# Dockerfile for image: http-to-mqtt
# 
# Sample docker build command:
# docker build --progress=plain --platform=linux/amd64 -f "Dockerfile" -t http-to-mqtt "."

FROM matlabruntime/r2023b/release/update9/308000000400000000

COPY ./applicationFilesForMATLABCompiler /usr/bin/mlrtapp
RUN chmod -R a+rX /usr/bin/mlrtapp/*

RUN if ["$(getent passwd appuser | cut -d: -f1)" = ""] ; then useradd -ms /bin/bash appuser ; fi
USER appuser

ENTRYPOINT ["/opt/matlabruntime/R2023b/bin/glnxa64/muserve", "-a", "/usr/bin/mlrtapp/http_to_mqtt.ctf"]
