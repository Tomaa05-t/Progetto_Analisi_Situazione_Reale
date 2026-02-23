#!/bin/bash
# Domanda8.sh - Backup database centro sportivo con menu interattivo
# Funziona sia da terminale che da Streamlit

CSV_FILE="centro_sportivo.csv"
BACKUP_DIR="./backups"
LOG_DIR="./logs_backup"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { 
    mkdir -p "$LOG_DIR"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_DIR/backup_auto.log"
}

# FUNZIONE: Crea backup
crea_backup() {
    if [ ! -f "$CSV_FILE" ]; then
        echo -e "${RED}Errore: $CSV_FILE non trovato${NC}"
        return 1
    fi

    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    mkdir -p "$BACKUP_DIR" "$LOG_DIR"
    
    echo "📦 Creazione backup in corso..."
    tar -czf "$BACKUP_DIR/centro_sportivo_backup_${TIMESTAMP}.tar.gz" "$CSV_FILE" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Backup creato: centro_sportivo_backup_${TIMESTAMP}.tar.gz${NC}"
        log "Backup creato OK"
        
        # Rotazione: mantieni ultimi 7 backup
        ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null | tail -n +8 | xargs rm -f 2>/dev/null
        
        return 0
    else
        echo -e "${RED}✗ Errore durante il backup${NC}"
        log "Errore durante il backup"
        return 1
    fi
}

# FUNZIONE: Vedi backup disponibili
vedi_backup() {
    BACKUPS=($(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null))

    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠️  Nessun backup trovato${NC}"
        return 1
    fi

    echo ""
    echo "📋 BACKUP DISPONIBILI:"
    echo "════════════════════════════════════════"
    
    for i in "${!BACKUPS[@]}"; do
        FILENAME=$(basename "${BACKUPS[$i]}")
        SIZE=$(du -h "${BACKUPS[$i]}" | cut -f1)
        
        if [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8})_([0-9]{6})\.tar\.gz ]]; then
            DATA="${BASH_REMATCH[1]}"
            ORA="${BASH_REMATCH[2]}"
            echo "  $((i+1)). ${DATA:6:2}/${DATA:4:2}/${DATA:0:4} alle ${ORA:0:2}:${ORA:2:2} - $SIZE"
        fi
    done
    
    echo "════════════════════════════════════════"
    return 0
}

# FUNZIONE: Ripristina backup
ripristina_backup() {
    BACKUPS=($(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null))

    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠️  Nessun backup disponibile${NC}"
        return 1
    fi

    echo ""
    echo "📋 BACKUP DISPONIBILI:"
    for i in "${!BACKUPS[@]}"; do
        FILENAME=$(basename "${BACKUPS[$i]}")
        if [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8})_([0-9]{6})\.tar\.gz ]]; then
            DATA="${BASH_REMATCH[1]}"
            ORA="${BASH_REMATCH[2]}"
            echo "  $((i+1)). ${DATA:6:2}/${DATA:4:2}/${DATA:0:4} alle ${ORA:0:2}:${ORA:2:2}"
        fi
    done

    read -p "Quale backup? (0=annulla): " SCELTA
    
    if [ "$SCELTA" == "0" ] || [ "$SCELTA" -lt 1 ] || [ "$SCELTA" -gt ${#BACKUPS[@]} ]; then
        echo "Operazione annullata"
        return 1
    fi

    BACKUP_SCELTO="${BACKUPS[$((SCELTA-1))]}"
    FILENAME=$(basename "$BACKUP_SCELTO")
    
    if [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8}) ]]; then
        DATA="${BASH_REMATCH[1]}"
    else
        DATA=$(date +"%Y%m%d")
    fi
    
    OUTPUT_FILE="centro_sportivo_ripristino_${DATA}.csv"

    echo "📥 Estrazione backup..."
    tar -xzf "$BACKUP_SCELTO" -O > "$OUTPUT_FILE" 2>/dev/null

    if [ $? -eq 0 ]; then
        NUM_RIGHE=$(wc -l < "$OUTPUT_FILE")
        echo -e "${GREEN}✓ Ripristino riuscito!${NC}"
        echo "📄 File creato: $OUTPUT_FILE ($NUM_RIGHE righe)"
        echo "💡 Per sostituire l'originale: cp $OUTPUT_FILE $CSV_FILE"
        log "Backup ripristinato: $OUTPUT_FILE"
        return 0
    else
        echo -e "${RED}✗ Errore durante il ripristino${NC}"
        return 1
    fi
}

# FUNZIONE: Cerca utente
cerca_utente() {
    BACKUPS=($(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null))
    
    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠️  Nessun backup disponibile${NC}"
        return 1
    fi

    echo ""
    echo "📋 BACKUP DISPONIBILI:"
    for i in "${!BACKUPS[@]}"; do
        FILENAME=$(basename "${BACKUPS[$i]}")
        if [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8})_([0-9]{6})\.tar\.gz ]]; then
            DATA="${BASH_REMATCH[1]}"
            ORA="${BASH_REMATCH[2]}"
            echo "  $((i+1)). ${DATA:6:2}/${DATA:4:2}/${DATA:0:4} alle ${ORA:0:2}:${ORA:2:2}"
        fi
    done

    read -p "Quale backup? (0=annulla): " SCELTA
    
    if [ "$SCELTA" == "0" ] || [ "$SCELTA" -lt 1 ] || [ "$SCELTA" -gt ${#BACKUPS[@]} ]; then
        echo "Operazione annullata"
        return 1
    fi

    BACKUP_SCELTO="${BACKUPS[$((SCELTA-1))]}"

    echo ""
    echo "Cerca per: 1.ID  2.Nome  3.Cognome  4.Email  5.Sport"
    read -p "Scegli [1-5]: " TIPO
    read -p "Cosa cerchi? " VALORE

    if [ -z "$VALORE" ]; then
        echo -e "${RED}Valore non valido${NC}"
        return 1
    fi

    echo "🔍 Cerco '$VALORE'..."

    # Estrai il file tar in un file temporaneo
    TMP_CSV="/tmp/backup_search_$$.csv"
    tar -xzf "$BACKUP_SCELTO" -O > "$TMP_CSV" 2>/dev/null
    
    if [ ! -f "$TMP_CSV" ] || [ ! -s "$TMP_CSV" ]; then
        echo -e "${RED}Errore nell'estrazione del backup${NC}"
        rm -f "$TMP_CSV"
        return 1
    fi

    # Estrai l'header
    HEADER=$(head -n 1 "$TMP_CSV")
    
    if [ -z "$HEADER" ]; then
        echo -e "${RED}Errore: header vuoto${NC}"
        rm -f "$TMP_CSV"
        return 1
    fi

    # Cerca nel file temporaneo
    RISULTATI=""
    case $TIPO in
        1) RISULTATI=$(awk -F';' -v v="$VALORE" 'NR>1 && $1==v {print}' "$TMP_CSV") ;;
        2) RISULTATI=$(awk -F';' -v v="$VALORE" 'NR>1 && $2==v {print}' "$TMP_CSV") ;;
        3) RISULTATI=$(awk -F';' -v v="$VALORE" 'NR>1 && $3==v {print}' "$TMP_CSV") ;;
        4) RISULTATI=$(awk -F';' -v v="$VALORE" 'NR>1 && $5==v {print}' "$TMP_CSV") ;;
        5) RISULTATI=$(awk -F';' -v v="$VALORE" 'NR>1 && $6==v {print}' "$TMP_CSV") ;;
        *) echo -e "${RED}Scelta non valida${NC}"; rm -f "$TMP_CSV"; return 1 ;;
    esac

    if [ -z "$RISULTATI" ]; then
        echo -e "${YELLOW}❌ Nessun risultato trovato per '$VALORE'${NC}"
        rm -f "$TMP_CSV"
        return 1
    fi

    [[ "$BACKUP_SCELTO" =~ centro_sportivo_backup_([0-9]{8}) ]] && DATA="${BASH_REMATCH[1]}" || DATA=$(date +"%Y%m%d")
    
    NUM=$(echo "$RISULTATI" | wc -l)

    if [ "$NUM" -eq 1 ]; then
        OUTPUT_FILE="utente_ripristinato_${DATA}.csv"
        echo "$HEADER" > "$OUTPUT_FILE"
        echo "$RISULTATI" >> "$OUTPUT_FILE"
        
        echo -e "${GREEN}✓ Trovato!${NC}"
        echo ""
        echo "$RISULTATI" | awk -F';' '{
            print "ID:    "$1
            print "Nome:  "$2" "$3
            print "Email: "$5
            print "Sport: "$6
        }'
    else
        OUTPUT_FILE="utenti_trovati_${DATA}.csv"
        echo "$HEADER" > "$OUTPUT_FILE"
        echo "$RISULTATI" >> "$OUTPUT_FILE"
        
        echo -e "${GREEN}✓ Trovati $NUM utenti${NC}"
        echo ""
        echo "$RISULTATI" | awk -F';' '{printf "%2d. %s | %s %s | %s\n", NR, $1, $2, $3, $5}'
    fi
    
    echo ""
    echo "📄 Salvati in: $OUTPUT_FILE"
    
    # Cleanup
    rm -f "$TMP_CSV"
    return 0
}

# FUNZIONE: Statistiche
statistiche() {
    BACKUPS=($(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null))
    
    echo ""
    echo "📊 STATISTICHE BACKUP:"
    echo "════════════════════════════════════════"
    echo "Numero di backup: ${#BACKUPS[@]}"
    
    if [ ${#BACKUPS[@]} -gt 0 ]; then
        TOTAL_SIZE=$(du -ch "$BACKUP_DIR"/*.tar.gz 2>/dev/null | tail -1 | cut -f1)
        echo "Spazio totale: $TOTAL_SIZE"
        
        FILENAME=$(basename "${BACKUPS[0]}")
        if [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8})_([0-9]{6}) ]]; then
            DATA="${BASH_REMATCH[1]}"
            ORA="${BASH_REMATCH[2]}"
            echo "Ultimo backup: ${DATA:6:2}/${DATA:4:2}/${DATA:0:4} alle ${ORA:0:2}:${ORA:2:2}"
        fi
    fi
    
    echo ""
    echo "📋 ULTIMI 5 BACKUP:"
    echo "════════════════════════════════════════"
    if [ -f "$LOG_DIR/backup_auto.log" ]; then
        tail -5 "$LOG_DIR/backup_auto.log" | sed 's/^/  /'
    else
        echo "  Nessun log disponibile"
    fi
    
    return 0
}

# MENU PRINCIPALE
menu_principale() {
    while true; do
        echo ""
        echo "╔════════════════════════════════════════╗"
        echo "║  BACKUP DATABASE CENTRO SPORTIVO      ║"
        echo "╚════════════════════════════════════════╝"
        echo ""
        echo "1. 📦 Crea backup"
        echo "2. 📋 Vedi backup disponibili"
        echo "3. 📥 Ripristina backup completo"
        echo "4. 🔍 Cerca utente nel backup"
        echo "5. 📊 Visualizza statistiche"
        echo "6. 🚪 Esci"
        echo ""
        read -p "Scegli [1-6]: " SCELTA

        case $SCELTA in
            1)
                echo ""
                crea_backup
                ;;
            2)
                vedi_backup
                ;;
            3)
                ripristina_backup
                ;;
            4)
                cerca_utente
                ;;
            5)
                statistiche
                ;;
            6)
                echo ""
                echo -e "${GREEN}👋 Arrivederci!${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Scelta non valida${NC}"
                sleep 1
                ;;
        esac
    done
}

# Controlla che il CSV esista
if [ ! -f "$CSV_FILE" ]; then
    echo -e "${RED}Errore: $CSV_FILE non trovato${NC}"
    exit 1
fi

# Se eseguito con parametri, esegui l'azione (per Streamlit)
if [ $# -gt 0 ]; then
    case $1 in
        "backup")
            crea_backup
            exit $?
            ;;
        "list")
            vedi_backup
            exit $?
            ;;
        "stats")
            statistiche
            exit $?
            ;;
        *)
            echo "Uso: $0 [backup|list|stats]"
            exit 1
            ;;
    esac
else
    # Se eseguito senza parametri, mostra il menu (da terminale)
    menu_principale
fi