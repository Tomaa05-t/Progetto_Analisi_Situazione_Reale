#!/bin/bash

# --- CONFIGURAZIONE ---
DATABASE_FINALE="centro_sportivo.csv"
REPORT_ERRORI="report_errori.txt"

# Inizializziamo il file finale con l'intestazione se non esiste
if [ ! -f "$DATABASE_FINALE" ]; then
    echo "ID;Nome;Cognome;Data_Scadenza;Sport" > "$DATABASE_FINALE"
    echo "Database creato con intestazione."
fi

echo "--- IMPORTAZIONE DATI CENTRO SPORTIVO ---"
echo "Inserisci il nome del file da importare (es. iscritti_piscina.csv):"
read FILE_SORGENTE

# 1. Verifica esistenza file
if [ ! -f "$FILE_SORGENTE" ]; then
    echo "$(date): Errore - Il file $FILE_SORGENTE non esiste." >> "$REPORT_ERRORI"
    echo "Errore: File non trovato! Controlla il report errori."
    exit 1
fi

echo "A quale sport appartiene questo database? (es. Tennis, Piscina, Palestra):"
read SPORT_NOME

echo "Importazione di $FILE_SORGENTE per lo sport $SPORT_NOME in corso..."

# 2. Elaborazione dati
# Controlliamo se il file ha dati oltre l'intestazione
RIGHE=$(wc -l < "$FILE_SORGENTE")

if [ "$RIGHE" -le 1 ]; then
    echo "$(date): Salto file $FILE_SORGENTE - Motivo: File vuoto o solo intestazione." >> "$REPORT_ERRORI"
    echo "Attenzione: Il file non contiene dati utili."
else
    # Prendiamo dalla riga 2 in poi, e per ogni riga aggiungiamo lo sport in fondo

    tail -n +2 "$FILE_SORGENTE" | while read -r riga; do
        # 1. Pulizia: rimuoviamo il carattere 'ritorno a capo' (\r) di Windows
        riga_pulita=$(echo "$riga" | tr -d '\r')

        # 2. Controllo se la riga è vuota dopo la pulizia
        if [ ! -z "$riga_pulita" ]; then
            # 3. Scriviamo tutto sulla stessa riga separando con il punto e virgola
            echo "${riga_pulita};$SPORT_NOME" >> "$DATABASE_FINALE"
        else
            echo "$(date): Riga vuota saltata in $FILE_SORGENTE" >> "$REPORT_ERRORI"
        fi
    done
    echo "Importazione completata con successo!"
fi

echo "------------------------------------------"
echo "Stato Database: $(wc -l < "$DATABASE_FINALE") righe."
echo "Controlla $REPORT_ERRORI per eventuali anomalie."