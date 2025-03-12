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

        // 2. Einheiten: ch0_einheit bis ch11_einheit
        const einheiten = [];
        for (let i = 0; i < 12; i++) {
            einheiten.push(req.body[`ch${i}_einheit`] || "");
        }

        // 3. Messrichtungen: ch0_messrichtung bis ch11_messrichtung
        const messrichtungen = [];
        for (let i = 0; i < 12; i++) {
            messrichtungen.push(req.body[`ch${i}_messrichtung`] || "");
        }

        // 4. Notizen: ch0_notes bis ch11_notes
        const notizen = [];
        for (let i = 0; i < 12; i++) {
            notizen.push(req.body[`ch${i}_notes`] || "");
        }

        // 5. measurementQuantity: ch0_measurementQuantity bis ch11_measurementQuantity
        const measurementQuantity = [];
        for (let i = 0; i < 12; i++) {
            measurementQuantity.push(req.body[`ch${i}_measurementQuantity`] || "");
        }

        // 6. swich_startStop: Übergabe als String
        const swich_startStop = req.body.swich_startStop || "";

        // 7. Sensitivities: ch0_sensitivity bis ch11_sensitivity
        const sensitivities = [];
        for (let i = 0; i < 12; i++) {
            sensitivities.push(parseFloat(req.body[`ch${i}_sensitivity`]) || 0);
        }

        // 8. abtastrate_hz: als einzelne Zahl in einem Array
        const abtastrate_hz = [parseFloat(req.body.abtastrate_hz) || 0];

        // 9. measurementName: als String
        const measurementName = req.body.measurementName || "";

        // Zusammenbau des neuen MATLAB-kompatiblen Bodys:
        // Positionen:
        //  0-11: channels
        // 12-23: einheiten
        // 24-35: messrichtungen
        // 36-47: notizen
        // 48-59: measurementQuantity
        // 60: swich_startStop
        // 61: sensitivities (als Array)
        // 62: abtastrate_hz (als Array)
        // 63: measurementName
        const newBody = {
            nargout: 1,
            rhs: [
                ...channels,           // 0-11: Channels
                ...einheiten,          // 12-23: Einheiten
                ...messrichtungen,     // 24-35: Messrichtungen
                ...notizen,            // 36-47: Notizen
                ...measurementQuantity, // 48-59: MeasurementQuantity
                swich_startStop,       // 60: swich_startStop
                sensitivities,         // 61: Sensitivities
                abtastrate_hz,         // 62: Abtastrate_hz
                measurementName        // 63: MeasurementName
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
