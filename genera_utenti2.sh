#!/bin/bash

# Ci spostiamo nella cartella dove risiede lo script
cd "$(dirname "$0")"

OUTPUT="centro_sportivo.csv"

echo "Verifica file in corso..."

# Controllo se i file esistono prima di iniziare
if [[ ! -f "piscina.csv" || ! -f "palestra.csv" || ! -f "tennis.csv" ]]; then
    echo "Errore: Uno o più file CSV non sono stati trovati nella cartella!"
    ls *.csv  # Ti mostra quali file CSV vede effettivamente
    exit 1
fi

echo "Inizio unione..."
head -n 1 piscina.csv > "$OUTPUT"
tail -q -n +2 piscina.csv >> "$OUTPUT"
tail -q -n +2 palestra.csv >> "$OUTPUT"
tail -q -n +2 tennis.csv >> "$OUTPUT"

echo "Successo! Creato: $OUTPUT"