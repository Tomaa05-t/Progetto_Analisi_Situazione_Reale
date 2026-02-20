#!/bin/bash

# Usiamo localhost per il test reale, simulando l'IP del termostato
TARGET_IP="127.0.0.1" 
PORTA_SERVIZIO=22  # Usiamo la porta SSH che abbiamo attivato prima
LOG_FILE="log_manutenzione.txt"

echo "--- DIAGNOSTICA TERMOSTATO PISCINA ---"
echo ""
echo "Analisi del dispositivo all'indirizzo: $TARGET_IP"
echo "------------------------------------------------"

# 1. TEST HARDWARE (PING)
echo "Fase 1: Verifica connettività di rete (ICMP)..."
if ping.exe -n 1 $TARGET_IP > /dev/null; then
    echo "[OK] Hardware raggiungibile."
    
    # 2. TEST SOFTWARE (PORT SCAN)
    # Verifichiamo se la porta del servizio è aperta
    echo "Fase 2: Verifica servizio web (Porta $PORTA_SERVIZIO)..."
    
    # Questo comando prova ad aprire una connessione sulla porta 22
    if (echo > /dev/tcp/$TARGET_IP/$PORTA_SERVIZIO) >/dev/null 2>&1; then
        echo "[OK] Il servizio risponde correttamente."
        echo "$(date): Diagnosi su $TARGET_IP - Tutto funzionante." >> $LOG_FILE
        exit 0
    else
        echo "[ERRORE] Hardware acceso, ma il SERVIZIO non risponde."
        echo "[DIAGNOSI] Guasto software o processo bloccato."
        echo "$(date): Errore Software su $TARGET_IP (Porta $PORTA_SERVIZIO chiusa)." >> $LOG_FILE
        exit 1
    fi

else
    echo "[CRITICO] Il dispositivo non risponde al ping."
    echo "[DIAGNOSI] Dispositivo spento, cavo scollegato o blackout."
    echo "$(date): DOWN TOTALE $TARGET_IP - Verificare hardware." >> $LOG_FILE
    exit 1
fi

echo "------------------------------------------------"
echo "Analisi completata. Risultato salvato in $LOG_FILE"