#!/bin/bash

# --- CONFIGURAZIONE ---
DATABASE_FINALE="centro_sportivo.csv"
REPORT_ERRORI="report_errori.txt"

# 1. Inizializzazione con l'ordine esatto richiesto (11 Colonne)
# 1.ID, 2.Nome, 3.Cognome, 4.Data_Nascita, 5.Email, 6.Sport, 
# 7.Abbonamento, 8.Scadenza_Certificato, 9.Ultimo_Accesso, 10.Scadenza_Abbonamento, 11.Ban
if [ ! -f "$DATABASE_FINALE" ]; then
    echo "ID;Nome;Cognome;Data_Nascita;Email;Sport;Abbonamento;Scadenza_Certificato;Ultimo_Accesso;Scadenza_Abbonamento;Ban" > "$DATABASE_FINALE"
    echo "Database creato con struttura a 11 colonne (incluso Ban)."
fi

echo "--- IMPORTAZIONE DATI CENTRO SPORTIVO ---"
echo "Inserisci il nome del file da importare (es. iscritti_piscina.csv):"
read FILE_SORGENTE

if [ ! -f "$FILE_SORGENTE" ]; then
    echo "$(date): Errore - File $FILE_SORGENTE non trovato." >> "$REPORT_ERRORI"
    echo "Errore: File non trovato!"
    exit 1
fi

echo "Inserisci lo Sport per questo file (es. Piscina):"
read SPORT_NOME

echo "Importazione in corso..."

# 2. Elaborazione riga per riga
# Leggiamo il file riga per riga
    tail -n +2 "$FILE_SORGENTE" | while read -r riga; do
        # 1. Pulizia dai caratteri Windows (\r)
        riga_pulita=$(echo "$riga" | tr -d '\r')

        if [ ! -z "$riga_pulita" ]; then
            # 2. SMONTAGGIO della riga originale (usando il punto e virgola come separatore)
            # Immaginiamo che il tuo file sorgente sia: ID,Nome,Cognome,Nascita,Email,Abbonamento,ScadenzaCert,UltimoAcc,ScadenzaAbbo,Ban
            
            ID=$(echo "$riga_pulita" | cut -d',' -f1)
            NOME=$(echo "$riga_pulita" | cut -d',' -f2)
            COGNOME=$(echo "$riga_pulita" | cut -d',' -f3)
            NASCITA=$(echo "$riga_pulita" | cut -d',' -f4)
            EMAIL=$(echo "$riga_pulita" | cut -d',' -f5)
            ABBONAMENTO=$(echo "$riga_pulita" | cut -d',' -f6)
            CERTIFICATO=$(echo "$riga_pulita" | cut -d',' -f7)
            ACCESSO=$(echo "$riga_pulita" | cut -d',' -f8)
            SCAD_ABBO=$(echo "$riga_pulita" | cut -d',' -f9)
            # Il ban originale lo ignoriamo o lo leggiamo dal file (f10)

            # 3. RIMONTAGGIO nell'ordine richiesto (11 colonne):
            # ID(1);Nome(2);Cognome(3);Nascita(4);Email(5);Sport(6);Abbo(7);Cert(8);Acc(9);Scad_Abbo(10);Ban(11)
            echo "${ID};${NOME};${COGNOME};${NASCITA};${EMAIL};${SPORT_NOME};${ABBONAMENTO};${CERTIFICATO};${ACCESSO};${SCAD_ABBO};NO" >> "$DATABASE_FINALE"
        fi
    done

echo "Importazione completata. Campo 'Ban' impostato di default su 'NO'."
echo "------------------------------------------"