#!/bin/bash

# --- CONFIGURAZIONE ---
USER="admin"
SERVER_IP="5.96.17.218"  # queste 3 voci indicano variabili, servono così se in futuro cambia tipo l'ip del server, si modifica velocemente
DB_PATH="/home/admin/gestione"
TARGET_FILE="centro_sportivo.csv" #

FULL_PATH="$REMOTE_DIR/$TARGET_FILE" #crea il percorso completo gestione -> csv

echo "Tentativo di connessione sicura al server $SERVER_IP..."

# Eseguiamo un comando remoto tramite SSH per verificare il file
# -f controlla se il file esiste, -s se non è vuoto

#ssh $USER@$SERVER_IP, serve ad aprire una connessione criptata verso il server
#tutto quello dopo non viene eseguito il locale, ma spedito al server ed eseguito lìe
#if [ -f $DB_PATH ]; then, controlla se esiste un file (il db)
ssh $USER@$SERVER_IP "if [ -f $FULL_PATH ]; then 
                        echo 'Connessione riuscita: Il Database esiste.';
                        echo 'Ultime 3 righe del file:';
                        tail -n 3 $FULL_PATH;
                      else 
                        echo 'Errore: Database non trovato sul server remoto.';
                      fi"

if [ $? -eq 0 ]; then #$? prende l'output dell'ultimo comando(ssh) e l'output è 0=tutto ok, altro numero=problema
    echo "Operazione conclusa con successo."
else
    echo "Errore di rete o di autenticazione SSH."
fi

