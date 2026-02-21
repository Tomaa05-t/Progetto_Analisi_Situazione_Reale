#!/bin/bash
#ho definito il mio pc come server ssh(il db), installando la funzionalità, e poi ho ipotizzato tramite questo script il collegamento al server, che se funziona restituirà le ultime 3 righe del db

USER="admin_centro" 
SERVER_IP="127.0.0.1" 
REMOTE_PATH="C:\gestione\centro_sportivo.csv" #posizione del db nel server

echo "==============================================="
echo "   CONNESSIONE AL DATABASE CENTRO SPORTIVO     "
echo "==============================================="
echo "Tentativo di accesso remoto a: $SERVER_IP"
echo "-----------------------------------------------"

#ssh crea un tunnel criptato verso un altro pc
#powershell -command: dice al server di eseguire con powershell ciò che segue
    #                                         controlla se il file esiste,    legge il contenuto e estarre le ultime 3 righe,   se il file non esite stampa l'errore
ssh "$USER@$SERVER_IP" "powershell -Command \"if (Test-Path '$REMOTE_PATH') { Get-Content '$REMOTE_PATH' -Tail 3 } else { Write-Error 'File non trovato' }\""

if [ $? -eq 0 ]; then #$? se l'ultimo comando ha avtuto esito positivo (0), stampa operax conclusa
    echo "-----------------------------------------------"
    echo "Operazione conclusa con successo."
else
    echo "-----------------------------------------------"
    echo "Errore: Connessione fallita o file mancante su $SERVER_IP."
fi