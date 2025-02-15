const express = require('express');
const cors = require('cors');
const axios = require('axios');

const app = express();
const PORT = 5000; // Intern verwendeter Port

// Middleware für JSON-Parsing
app.use(express.json());

// CORS aktivieren
app.use(cors());

/**
 * Transformiert die eingehende JSON-Nachricht in das von MATLAB erwartete Format.
 */
app.post('/proxy', async (req, res) => {
    try {
        console.log("Original Body von Grafana:", req.body);

        // 1. ch_checkboxes: Erhalte Array und fülle auf 12 Einträge auf
        const checkboxes = Array.isArray(req.body.ch_checkboxes) ? req.body.ch_checkboxes : [];
        while (checkboxes.length < 12) {
            checkboxes.push("");
        }
        const channels = checkboxes.slice(0, 12);

        // 2. Einheiten: ch1_einheit bis ch12_einheit
        const einheiten = [];
        for (let i = 1; i <= 12; i++) {
            einheiten.push(req.body[`ch${i}_einheit`] || "");
        }

        // 3. Messrichtungen: ch1_messrichtung bis ch12_messrichtung
        const messrichtungen = [];
        for (let i = 1; i <= 12; i++) {
            messrichtungen.push(req.body[`ch${i}_messrichtung`] || "");
        }

        // 4. swich_startStop: Übergabe als String
        const swich_startStop = req.body.swich_startStop || "";

        // 5. Sensitivities: ch1_sensitivity bis ch12_sensitivity
        const sensitivities = [];
        for (let i = 1; i <= 12; i++) {
            sensitivities.push(parseFloat(req.body[`ch${i}_sensitivity`]) || 0);
        }

        // 6. abtastrate_hz: als einzelne Zahl in einem Array
        const abtastrate_hz = [parseFloat(req.body.abtastrate_hz) || 0];

        // Zusammenbau des neuen MATLAB-kompatiblen Bodys
        const newBody = {
            nargout: 1,
            rhs: [
                ...channels,         // Positionen 0-11: Einzelne Channels
                ...einheiten,        // Positionen 12-23: Einheiten
                ...messrichtungen,   // Positionen 24-35: Messrichtungen
                swich_startStop,     // Position 36: "start" oder "stop"
                sensitivities,       // Position 37: Array der Sensitivities (12 Werte)
                abtastrate_hz        // Position 38: Array mit abtastrate_hz
            ]
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
        if (error.response) {
            console.error("Antwort vom Microservice:", error.response.data);
        }
        res.status(500).json({ error: "Fehler beim Weiterleiten der Anfrage" });
    }
});

// Starte den Proxy-Server
app.listen(PORT, () => {
    console.log(`Proxy-Server läuft auf http://localhost:${PORT}`);
});
