#!/bin/bash

# Script: Domanda8.sh - Backup Automatico Database Centro Sportivo

# Descrizione: Crea un backup compresso del file CSV principale e lo salva
#              in una cartella dedicata con timestamp

# Uso: ./Domanda8.sh [file_csv] [cartella_backup]
#      Se non specificati, usa i valori predefiniti

# Esempio: ./Domanda8.sh centro_sportivo.csv ./backups

# File CSV da backuppare (può essere passato come primo parametro)
CSV_FILE="${1:-centro_sportivo.csv}"

# Cartella dove salvare i backup (può essere passata come secondo parametro)
BACKUP_DIR="${2:-./backups}"

# Formato del timestamp per il nome del file backup
# Formato: YYYYMMDD_HHMMSS (es: 20250206_183045)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Nome del file di backup
BACKUP_FILE="centro_sportivo_backup_${TIMESTAMP}.tar.gz"


# VALIDAZIONE INPUT


# Verifica che il file CSV esista
if [ ! -f "$CSV_FILE" ]; then
    echo "ERRORE: Il file '$CSV_FILE' non esiste!"
    echo "Uso: $0 [file_csv] [cartella_backup]"
    exit 1
fi


# CREAZIONE DIRECTORY BACKUP


# Crea la cartella backup se non esiste
# mkdir -p crea anche le directory parent se necessario
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Creazione cartella backup: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Verifica che la creazione sia andata a buon fine
    if [ $? -ne 0 ]; then
        echo "ERRORE: Impossibile creare la cartella $BACKUP_DIR"
        exit 2
    fi
fi

# CREAZIONE BACKUP
echo "BACKUP DATABASE CENTRO SPORTIVO"
echo "File sorgente: $CSV_FILE"
echo "Dimensione: $(du -h "$CSV_FILE" | cut -f1)"
echo "Destinazione: $BACKUP_DIR/$BACKUP_FILE"
echo "Timestamp: $(date '+%d/%m/%Y %H:%M:%S')"
echo ""

# Crea l'archivio compresso tar.gz
# -c: crea un nuovo archivio
# -z: comprime con gzip
# -f: specifica il nome del file di output
tar -czf "$BACKUP_DIR/$BACKUP_FILE" "$CSV_FILE" 2>/dev/null

# Verifica che il backup sia stato creato correttamente
if [ $? -eq 0 ] && [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
    echo "Backup completato con successo!"
    echo ""
    echo "Dettagli backup:"
    echo "- File backup: $BACKUP_FILE"
    echo "- Dimensione compressa: $(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)"
    echo "- Posizione: $BACKUP_DIR/"
    
    # Calcola il rapporto di compressione
    ORIG_SIZE=$(stat -c%s "$CSV_FILE" 2>/dev/null)
    BACKUP_SIZE=$(stat -c%s "$BACKUP_DIR/$BACKUP_FILE" 2>/dev/null)
    
    if [ -n "$ORIG_SIZE" ] && [ -n "$BACKUP_SIZE" ] && [ "$ORIG_SIZE" -gt 0 ]; then
        COMPRESSION_RATIO=$(awk "BEGIN {printf \"%.1f\", ($ORIG_SIZE - $BACKUP_SIZE) * 100 / $ORIG_SIZE}")
        echo "- Compressione: ${COMPRESSION_RATIO}%"
    fi
    
    echo ""
    echo "========================================" 
else
    echo "ERRORE: Backup fallito!"
    exit 3
fi
# GESTIONE BACKUP VECCHI (OPZIONALE)
# Conta quanti backup esistono
NUM_BACKUPS=$(ls -1 "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null | wc -l)
echo "Backup totali presenti: $NUM_BACKUPS"

# Se ci sono più di 7 backup, elimina i più vecchi
# Questo mantiene solo gli ultimi 7 backup (una settimana se fatto giornalmente)
MAX_BACKUPS=7

if [ "$NUM_BACKUPS" -gt "$MAX_BACKUPS" ]; then
    echo ""
    echo "Pulizia backup vecchi (mantengo gli ultimi $MAX_BACKUPS)..."
    
    # ls -t ordina per tempo di modifica (più recenti prima)
    # tail -n +8 prende tutti tranne i primi 7
    # xargs rm elimina i file
    ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f
    
    echo "Backup vecchi eliminati"
fi

echo "========================================" 

# Per schedulare questo script ogni sera, aggiungi al crontab:
# crontab -e
# Poi inserisci:
# 0 22 * * * /path/to/Domanda8.sh /path/to/centro_sportivo.csv /path/to/backups
# (Questo esegue lo script ogni giorno alle 22:00)

exit 0
