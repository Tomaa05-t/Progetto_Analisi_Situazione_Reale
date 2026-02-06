#!/bin/bash

# --- CONFIGURAZIONE ---
USER="admin"
SERVER_IP="127.0.0.1"  # IP IPOTETICO DEL SERVER DEL CENTRO
DB_PATH="/home/admin/gestione/centro_sportivo.csv"

echo "Tentativo di connessione sicura al server $SERVER_IP..."

# Eseguiamo un comando remoto tramite SSH per verificare il file
# -f controlla se il file esiste, -s se non è vuoto
ssh $USER@$SERVER_IP "if [ -f $DB_PATH ]; then 
                        echo 'Connessione riuscita: Il Database esiste.';
                        echo 'Ultime 3 righe del file:';
                        tail -n 3 $DB_PATH;
                      else 
                        echo 'Errore: Database non trovato sul server remoto.';
                      fi"

if [ $? -eq 0 ]; then
    echo "Operazione conclusa con successo."
else
    echo "Errore di rete o di autenticazione SSH."
fi