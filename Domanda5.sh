#!/bin/bash

TARGET_IP="162.120.188.34" #var che contiene l'ip del termostato
LOG_FILE="log_manutenzione.txt" #nome del file in cui stampa i risultati

echo "--- DIAGNOSTICA TERMOSTATO PISCINA ---"
echo "Verifica connettività verso $TARGET_IP..."

# 1. Tentativo di PING (3 pacchetti, attesa massima 2 secondi)
if ping.exe -n 2 $TARGET_IP; then #controllo rete, manda 3 pacchetti al termostato e aspetta 2s tra un tentativo e l'altro
    echo "[OK] Il dispositivo è acceso e collegato alla rete." #ok il disp è connesso alla rete, hardware ok
    
    #ora inizia l'ipotesi
    echo "Verifica servizio web in corso..." #la rete è ok, vediamo se l'app lo rileva
    sleep 2 #pausa script di 2 sec per simulare la verifica
    

    echo "[ERRORE] L'interfaccia web del termostato non risponde (Porta 80 chiusa)." #rilevato guasto software, il ping è ok ma il disp non viene rilevato
    echo "$(date): Errore Software su $TARGET_IP - Richiesto riavvio forzato." >> $LOG_FILE #scrivo nel file log_manutenzione.txt l'errore
else #se inizialmente il ping ha fallito
    echo "[CRITICO] Il dispositivo non risponde al ping." #allora c'è un problema di hardware (disp spento, cavo rete rotto...)
    echo "[DIAGNOSI] Possibile guasto hardware, cavo scollegato o blackout."
    echo "$(date): Down totale $TARGET_IP - Verificare cablaggio." >> $LOG_FILE  #scrivo nel file log_manutenzione.txt l'errore
fi

echo "Report salvato in $LOG_FILE"  