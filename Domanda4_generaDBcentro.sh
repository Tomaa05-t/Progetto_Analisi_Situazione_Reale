#!/bin/bash

# configurazione variabili
DATABASE_FINALE="centro_sportivo.csv"
REPORT_ERRORI="report_errori.txt"

# se il file non esiste (! -f), lo creo con la struttura desiderata
if [ ! -f "$DATABASE_FINALE" ]; then
    echo "ID;Nome;Cognome;Data_Nascita;Email;Sport;Abbonamento;Scadenza_Certificato;Ultimo_Accesso;Scadenza_Abbonamento;Ban" > "$DATABASE_FINALE"
    echo "Database creato con struttura a 11 colonne (incluso Ban)."
fi

echo "--- IMPORTAZIONE DATI CENTRO SPORTIVO ---"
echo "Inserisci il nome del file da importare (es. iscritti_piscina.csv):"
read FILE_SORGENTE #inserimento da tastiera del db da importare

if [ ! -f "$FILE_SORGENTE" ]; then
    echo "$(date): Errore - File $FILE_SORGENTE non trovato." >> "$REPORT_ERRORI"
    echo "Errore: File non trovato!"
    exit 1
fi

echo "Inserisci lo Sport per questo file (es. Piscina):"
read SPORT_NOME


# Prendiamo l'ultima riga, estraiamo il primo campo (ID) e verifichiamo che sia un numero
ULTIMO_ID=$(tail -n 1 "$DATABASE_FINALE" | cut -d';' -f1)

# Se il database ha solo l'header o l'ID non è un numero, partiamo da 0
if [[ ! "$ULTIMO_ID" =~ ^[0-9]+$ ]]; then
    CONTATORE_ID=0
else
    CONTATORE_ID=$ULTIMO_ID
fi

echo "Importazione in corso..."

# tail -n +2 salta la prima riga (header)
tail -n +2 "$FILE_SORGENTE" | while read -r riga; do
#Pulizia dai caratteri invisibili di Windows, x non avevre problemi di formattazione (\r)
    riga_pulita=$(echo "$riga" | tr -d '\r')

    if [ ! -z "$riga_pulita" ]; then #riga vuota?
        # Incrementiamo l'ID per ogni riga valida
        ((CONTATORE_ID++))

         # smontaggio della riga originale (usando il punto e virgola come separatore)         
         
                NOME=$(echo "$riga_pulita" | cut -d',' -f2) #-d: quale è il delimitatore
                COGNOME=$(echo "$riga_pulita" | cut -d',' -f3)
                NASCITA=$(echo "$riga_pulita" | cut -d',' -f4)
                EMAIL=$(echo "$riga_pulita" | cut -d',' -f5)
                ABBONAMENTO=$(echo "$riga_pulita" | cut -d',' -f6)
                CERTIFICATO=$(echo "$riga_pulita" | cut -d',' -f7)
                ACCESSO=$(echo "$riga_pulita" | cut -d',' -f8)
                SCAD_ABBO=$(echo "$riga_pulita" | cut -d',' -f9)

                # rimontaggio della riga nell'ordine richiesto
                echo "${CONTATORE_ID};${NOME};${COGNOME};${NASCITA};${EMAIL};${SPORT_NOME};${ABBONAMENTO};${CERTIFICATO};${ACCESSO};${SCAD_ABBO};NO" >> "$DATABASE_FINALE"
            

        fi
    done

echo "Importazione completata. Campo 'Ban' impostato di default su 'NO'."
echo "------------------------------------------"