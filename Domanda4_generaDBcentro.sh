#!/bin/bash
# 1. Definiamo il file finale
OUTPUT="centro_sportivo.csv"

echo "Inizio unione dei database..."

# 2. Prendiamo l'intestazione (header) solo dal primo file e creiamo il file finale
head -n 1 iscritti_piscina.csv > "$OUTPUT"

# 3. Aggiungiamo i dati di tutti i file saltando la loro prima riga
# Usiamo 'tail -n +2' per iniziare a leggere dalla seconda riga (saltando l'header)
tail -q -n +2 iscritti_piscina.csv >> "$OUTPUT"
tail -q -n +2 iscritti_palestra.csv >> "$OUTPUT"
tail -q -n +2 iscritti_tennis.csv >> "$OUTPUT"


echo "Successo! Il file $OUTPUT è stato creato."


#scelta di importazione, l'utente sceglie scvrivendo iscritti_piscina, e inserisco anche che sport fanno perchè è ovvio che piscina fanno piscina e creare un report di cosa non è andato bene, perchè questo mon è stato inserito?