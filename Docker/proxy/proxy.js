const express = require('express');
const cors = require('cors');
const axios = require('axios');

const app = express();
const PORT = 5000; // Der Proxy läuft auf Port 5000

// Middleware für JSON-Parsing
app.use(express.json());

// CORS aktivieren
app.use(cors());

// Proxy-Endpoint für Business Forms
app.post('/proxy', async (req, res) => {
    try {
        console.log("Original Body von Grafana:", req.body);

        // Werte aus Grafana extrahieren
        const rhs1 = req.body.rhs1 || 0; // Standardwert 0, falls rhs1 fehlt
        const rhs2 = req.body.rhs2 || 0; // Standardwert 0, falls rhs2 fehlt

        // MATLAB-kompatiblen JSON-Body erstellen
        const newBody = {
            nargout: 1,
            rhs: [parseFloat(rhs1), parseFloat(rhs2)] // Konvertiere Strings zu Zahlen
        };

        console.log("Umgewandelter Body:", newBody);

        // Anfrage an den MATLAB-Microservice weiterleiten
        const response = await axios.post(
            'http://http_to_mqtt_service:9910/http_to_mqtt/httpToMqtt',
            newBody,
            { headers: { 'Content-Type': 'application/json' } }
        );

        // Antwort an Grafana zurückgeben
        res.json(response.data);
    } catch (error) {
        console.error("Fehler im Proxy:", error.message);

        // Fehlerdetails für Debugging
        if (error.response) {
            console.error("Antwort vom Microservice:", error.response.data);
        }

        res.status(500).json({ error: "Fehler beim Weiterleiten der Anfrage" });
    }
});

// Proxy starten
app.listen(PORT, () => {
    console.log(`Proxy-Server läuft auf http://localhost:${PORT}`);
});