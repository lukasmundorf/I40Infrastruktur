# Verwende ein leichtes Node.js-Image für ARM64 (funktioniert auch auf x86!)
FROM node:18-alpine

# Arbeitsverzeichnis im Container
WORKDIR /app

# Kopiere die Dateien in den Container
COPY package.json package-lock.json ./
RUN npm install

COPY proxy.js ./

# Starte den Proxy
CMD ["node", "proxy.js"]