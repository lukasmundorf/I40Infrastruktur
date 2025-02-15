# Verwende ein leichtes Node.js-Image (alpine-Version) – unterstützt ARM64 und x86
FROM node:18-alpine

# Setze das Arbeitsverzeichnis im Container
WORKDIR /app

# Kopiere package.json und package-lock.json in den Container
COPY package*.json ./

# Installiere Abhängigkeiten
RUN npm install

# Kopiere den Proxy-Code in den Container
COPY proxy.js ./

# Starte den Proxy
CMD ["node", "proxy.js"]
