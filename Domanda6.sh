#!/bin/bash

# configurazione variabili
SOGLIA_MINIMA=26
FILE_SENSORE="temperatura_sensore/temperatura_sensore.txt" # Il termostato virtuale
LOG_ALLARMI="allarmi_sensore_piscina.txt"
EMAIL_MANUTENZIONE="centroSportivo@manutenzione.it"
SCRIPT_TERMOSTATO="./Domanda5.sh"

echo "SISTEMA INTEGRATO DI CONTROLLO PISCINA"
echo ""
echo "Avvio diagnostica del termostato..."
echo ""

# Richiama il file di controllo del termostato
if ! bash "$SCRIPT_TERMOSTATO"; then
    echo "-----------------------------------------------"
    echo "!!ERRORE!!: Impossibile rilevare il termostato."
    echo "La diagnostica ha rilevato un guasto al sensore."
    echo "Il monitoraggio temperatura è bloccato."
    exit 1
fi


echo "-----------------------------------------------"
echo "Risposta sensore: OK. Lettura dei dati..."

# Lettura del dato dal sensore
TEMP=$(cat "$FILE_SENSORE")

echo "Lettura sensore: $TEMP°C"
echo "Soglia di sicurezza: $SOGLIA_MINIMA°C"
echo "-----------------------------------------------"

# Logica di Allarme
if [ "$TEMP" -lt "$SOGLIA_MINIMA" ]; then #-lt = less then
    echo "[!] ALLARME CRITICO: Temperatura vasca a $TEMP°C!"
    echo "Attivazione caldaie di emergenza e invio segnalazione..."

    echo "$(date): ALLARME! Rilevato valore critico: $TEMP°C" >> "temperatura_sensore/$LOG_ALLARMI"

    echo "Notifica inviata a: $EMAIL_MANUTENZIONE"
else
    echo "[OK] Temperatura ottimale ($TEMP°C). Sistema stabile."
fi