#!/bin/bash
# Script: Domanda8.sh - Backup e Ripristino Database Centro Sportivo

# Descrizione: Crea backup compressi del file CSV principale oppure ripristina
#              un backup precedente

# Uso Backup: ./Domanda8.sh backup [file_csv] [cartella_backup]
# Uso Ripristino: ./Domanda8.sh ripristino [file_backup.tar.gz]

# Esempio Backup: ./Domanda8.sh backup centro_sportivo.csv ./backups
# Esempio Ripristino: ./Domanda8.sh ripristino ./backups/centro_sportivo_backup_20260206_220000.tar.gz

# ============================================================================
# PARSING MODALITÀ
# ============================================================================

MODALITA="${1:-backup}"

# ============================================================================
# MODALITÀ RIPRISTINO
# ============================================================================

if [ "$MODALITA" == "ripristino" ] || [ "$MODALITA" == "restore" ]; then
    BACKUP_FILE="$2"
    
    # Verifica che sia stato specificato un file
    if [ -z "$BACKUP_FILE" ]; then
        echo "ERRORE: Specifica il file di backup da ripristinare"
        echo "Uso: $0 ripristino [file_backup.tar.gz]"
        echo ""
        echo "Backup disponibili:"
        ls -1t ./backups/centro_sportivo_backup_*.tar.gz 2>/dev/null | head -10
        exit 1
    fi
    
    # Verifica che il file di backup esista
    if [ ! -f "$BACKUP_FILE" ]; then
        echo "ERRORE: Il file di backup '$BACKUP_FILE' non esiste!"
        exit 1
    fi
    
    # Estrae la data dal nome del file (formato: centro_sportivo_backup_20260206_220000.tar.gz)
    FILENAME=$(basename "$BACKUP_FILE")
    
    # Estrae timestamp dal nome file (es: 20260206_220000)
    if [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8}_[0-9]{6})\.tar\.gz ]]; then
        TIMESTAMP="${BASH_REMATCH[1]}"
        DATA="${TIMESTAMP:0:8}"  # Primi 8 caratteri: YYYYMMDD
        ORA="${TIMESTAMP:9:6}"   # Ultimi 6 caratteri: HHMMSS
        
        # Formatta data leggibile
        ANNO="${DATA:0:4}"
        MESE="${DATA:4:2}"
        GIORNO="${DATA:6:2}"
        DATA_LEGGIBILE="${GIORNO}/${MESE}/${ANNO}"
        
        # Formatta ora leggibile
        ORE="${ORA:0:2}"
        MINUTI="${ORA:2:2}"
        SECONDI="${ORA:4:2}"
        ORA_LEGGIBILE="${ORE}:${MINUTI}:${SECONDI}"
    else
        echo "ERRORE: Formato nome file non valido!"
        echo "Atteso: centro_sportivo_backup_YYYYMMDD_HHMMSS.tar.gz"
        exit 1
    fi
    
    # Nome del file ripristinato
    OUTPUT_FILE="centro_sportivo_ripristino_${DATA}.csv"
    
    echo "========================================"
    echo "RIPRISTINO BACKUP CENTRO SPORTIVO"
    echo "========================================"
    echo "File backup: $FILENAME"
    echo "Data backup: $DATA_LEGGIBILE alle $ORA_LEGGIBILE"
    echo "File output: $OUTPUT_FILE"
    echo ""
    
    # Estrae il file dal backup
    tar -xzf "$BACKUP_FILE" -O > "$OUTPUT_FILE" 2>/dev/null
    
    # Verifica che il ripristino sia riuscito
    if [ $? -eq 0 ] && [ -f "$OUTPUT_FILE" ]; then
        echo "✓ Ripristino completato con successo!"
        echo ""
        echo "Dettagli file ripristinato:"
        echo "- Nome: $OUTPUT_FILE"
        echo "- Dimensione: $(du -h "$OUTPUT_FILE" | cut -f1)"
        echo "- Righe: $(wc -l < "$OUTPUT_FILE")"
        echo ""
        echo "Puoi ora usare questo file o sostituire l'originale:"
        echo "  cp $OUTPUT_FILE centro_sportivo.csv"
        echo "========================================"
    else
        echo "✗ ERRORE: Ripristino fallito!"
        exit 3
    fi
    
    exit 0
fi

# ============================================================================
# MODALITÀ BACKUP (codice originale)
# ============================================================================

# File CSV da backuppare
CSV_FILE="${2:-centro_sportivo.csv}"

# Cartella dove salvare i backup
BACKUP_DIR="${3:-./backups}"

# Timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Nome del file di backup
BACKUP_FILE="centro_sportivo_backup_${TIMESTAMP}.tar.gz"

# VALIDAZIONE INPUT
if [ ! -f "$CSV_FILE" ]; then
    echo "ERRORE: Il file '$CSV_FILE' non esiste!"
    echo "Uso: $0 backup [file_csv] [cartella_backup]"
    exit 1
fi

# CREAZIONE DIRECTORY BACKUP
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Creazione cartella backup: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    if [ $? -ne 0 ]; then
        echo "ERRORE: Impossibile creare la cartella $BACKUP_DIR"
        exit 2
    fi
fi

# CREAZIONE BACKUP
echo "========================================"
echo "BACKUP DATABASE CENTRO SPORTIVO"
echo "========================================"
echo "File sorgente: $CSV_FILE"
echo "Dimensione: $(du -h "$CSV_FILE" | cut -f1)"
echo "Destinazione: $BACKUP_DIR/$BACKUP_FILE"
echo "Timestamp: $(date '+%d/%m/%Y %H:%M:%S')"
echo ""

tar -czf "$BACKUP_DIR/$BACKUP_FILE" "$CSV_FILE" 2>/dev/null

if [ $? -eq 0 ] && [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
    echo "✓ Backup completato con successo!"
    echo ""
    echo "Dettagli backup:"
    echo "- File backup: $BACKUP_FILE"
    echo "- Dimensione compressa: $(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)"
    echo "- Posizione: $BACKUP_DIR/"
    
    ORIG_SIZE=$(stat -c%s "$CSV_FILE" 2>/dev/null)
    BACKUP_SIZE=$(stat -c%s "$BACKUP_DIR/$BACKUP_FILE" 2>/dev/null)
    
    if [ -n "$ORIG_SIZE" ] && [ -n "$BACKUP_SIZE" ] && [ "$ORIG_SIZE" -gt 0 ]; then
        COMPRESSION_RATIO=$(awk "BEGIN {printf \"%.1f\", ($ORIG_SIZE - $BACKUP_SIZE) * 100 / $ORIG_SIZE}")
        echo "- Compressione: ${COMPRESSION_RATIO}%"
    fi
    
    echo ""
else
    echo "✗ ERRORE: Backup fallito!"
    exit 3
fi

# GESTIONE BACKUP VECCHI
NUM_BACKUPS=$(ls -1 "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null | wc -l)
echo "Backup totali presenti: $NUM_BACKUPS"

MAX_BACKUPS=7

if [ "$NUM_BACKUPS" -gt "$MAX_BACKUPS" ]; then
    echo ""
    echo "Pulizia backup vecchi (mantengo gli ultimi $MAX_BACKUPS)..."
    ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f
    echo "✓ Backup vecchi eliminati"
fi

echo "========================================"
echo ""
echo "Per ripristinare un backup usa:"
echo "  $0 ripristino $BACKUP_DIR/$BACKUP_FILE"

exit 0