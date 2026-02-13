#!/bin/bash
################################################################################
# Domanda8.sh - Backup database centro sportivo
# Alessandro - 2026
#
# Uso: ./Domanda8.sh        -> menu interattivo
#      ./Domanda8.sh auto   -> backup automatico (per cron)
################################################################################

################################################################################
# CONFIGURARE CRON (su Codespaces va reinstallato ogni riavvio):
#   sudo apt-get update && sudo apt-get install -y cron
#   sudo service cron start
#   crontab -e
#   Aggiungi: 0 22 * * * cd /workspaces/Progetto_Analisi_Situazione_Reale && ./Domanda8.sh auto
################################################################################

# MODALITÀ AUTO (chiamata da cron)
if [ "$1" == "auto" ]; then
    CSV_FILE="centro_sportivo.csv"
    BACKUP_DIR="./backups"
    LOG_DIR="./logs_backup"
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="centro_sportivo_backup_${TIMESTAMP}.tar.gz"
    LOG_FILE="$LOG_DIR/backup_auto.log"
    
    # Funzione log
    log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }
    
    log "===== INIZIO BACKUP ====="
    
    # Verifica file esista
    if [ ! -f "$CSV_FILE" ]; then
        log "ERRORE: File $CSV_FILE non trovato"
        log "===== FINE (ERRORE) ====="
        exit 1
    fi
    
    mkdir -p "$BACKUP_DIR" "$LOG_DIR"
    
    ORIG_SIZE=$(du -h "$CSV_FILE" | cut -f1)
    NUM_RIGHE=$(wc -l < "$CSV_FILE")
    log "File: $CSV_FILE - $ORIG_SIZE - $NUM_RIGHE righe"
    
    # Crea backup compresso
    tar -czf "$BACKUP_DIR/$BACKUP_FILE" "$CSV_FILE" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
        log "OK! Backup: $BACKUP_FILE ($BACKUP_SIZE)"
        
        # Rotazione: mantiene ultimi 7
        NUM_BACKUPS=$(ls -1 "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null | wc -l)
        if [ "$NUM_BACKUPS" -gt 7 ]; then
            ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz | tail -n +8 | xargs rm -f
            log "Eliminati backup vecchi"
        fi
        
        # Log giornaliero
        echo "$(date '+%H:%M:%S') - $BACKUP_FILE - $BACKUP_SIZE" >> "$LOG_DIR/backup_$(date +"%Y-%m-%d").log"
        
        log "===== FINE BACKUP (OK) ====="
        exit 0
    else
        log "ERRORE: Backup fallito!"
        log "===== FINE (ERRORE) ====="
        exit 1
    fi
fi

################################################################################
# MODALITÀ INTERATTIVA
################################################################################

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CSV_FILE="centro_sportivo.csv"
BACKUP_DIR="./backups"

# Mostra menu
mostra_menu() {
    clear
    echo "========================================"
    echo "  BACKUP DATABASE CENTRO SPORTIVO"
    echo "========================================"
    echo ""
    echo "1. Crea backup"
    echo "2. Vedi backup disponibili"
    echo "3. Ripristina backup completo"
    echo "4. Cerca utente nel backup"
    echo "5. Esci"
    echo ""
    echo -n "Scegli [1-5]: "
}

# 1. Crea backup
crea_backup() {
    echo ""
    echo "========================================"
    echo "  CREAZIONE BACKUP"
    echo "========================================"
    echo ""
    
    if [ ! -f "$CSV_FILE" ]; then
        echo -e "${RED}Errore: File $CSV_FILE non trovato${NC}"
        read -p "Premi Invio..."
        return
    fi
    
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="centro_sportivo_backup_${TIMESTAMP}.tar.gz"
    mkdir -p "$BACKUP_DIR"
    
    echo "File: $CSV_FILE ($(du -h "$CSV_FILE" | cut -f1))"
    echo "Creazione backup..."
    
    tar -czf "$BACKUP_DIR/$BACKUP_FILE" "$CSV_FILE" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Backup creato${NC}"
        echo "File: $BACKUP_FILE ($(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1))"
        
        # Rotazione
        NUM_BACKUPS=$(ls -1 "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null | wc -l)
        if [ "$NUM_BACKUPS" -gt 7 ]; then
            echo "Elimino backup vecchi..."
            ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz | tail -n +8 | xargs rm -f
        fi
    else
        echo -e "${RED}✗ Errore${NC}"
    fi
    
    echo ""
    read -p "Premi Invio..."
}

# 2. Lista backup
vedi_backup() {
    echo ""
    echo "========================================"
    echo "  BACKUP DISPONIBILI"
    echo "========================================"
    echo ""
    
    BACKUPS=($(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null))
    
    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo -e "${YELLOW}Nessun backup trovato${NC}"
        echo ""
        read -p "Premi Invio..."
        return
    fi
    
    for i in "${!BACKUPS[@]}"; do
        FILENAME=$(basename "${BACKUPS[$i]}")
        SIZE=$(du -h "${BACKUPS[$i]}" | cut -f1)
        
        # Estrae data/ora dal nome: centro_sportivo_backup_YYYYMMDD_HHMMSS.tar.gz
        if [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8})_([0-9]{6})\.tar\.gz ]]; then
            DATA="${BASH_REMATCH[1]}"
            ORA="${BASH_REMATCH[2]}"
            echo "$((i+1)). ${DATA:6:2}/${DATA:4:2}/${DATA:0:4} alle ${ORA:0:2}:${ORA:2:2} - $SIZE"
        else
            echo "$((i+1)). $FILENAME - $SIZE"
        fi
    done
    
    echo ""
    read -p "Premi Invio..."
}

# 3. Ripristino completo
ripristino_completo() {
    echo ""
    echo "========================================"
    echo "  RIPRISTINO COMPLETO"
    echo "========================================"
    echo ""
    
    BACKUPS=($(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null))
    
    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo -e "${YELLOW}Nessun backup disponibile${NC}"
        read -p "Premi Invio..."
        return
    fi
    
    echo "Backup disponibili:"
    echo ""
    
    for i in "${!BACKUPS[@]}"; do
        FILENAME=$(basename "${BACKUPS[$i]}")
        if [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8})_([0-9]{6})\.tar\.gz ]]; then
            DATA="${BASH_REMATCH[1]}"
            ORA="${BASH_REMATCH[2]}"
            echo "$((i+1)). ${DATA:6:2}/${DATA:4:2}/${DATA:0:4} alle ${ORA:0:2}:${ORA:2:2}"
        fi
    done
    
    echo ""
    echo -n "Quale backup? [1-${#BACKUPS[@]}] (0=annulla): "
    read SCELTA
    
    if [ "$SCELTA" == "0" ]; then return; fi
    if [ "$SCELTA" -lt 1 ] || [ "$SCELTA" -gt ${#BACKUPS[@]} ]; then
        echo -e "${RED}Scelta non valida${NC}"
        read -p "Premi Invio..."
        return
    fi
    
    BACKUP_SCELTO="${BACKUPS[$((SCELTA-1))]}"
    FILENAME=$(basename "$BACKUP_SCELTO")
    
    # Estrae data per nome output
    if [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8})_([0-9]{6})\.tar\.gz ]]; then
        DATA="${BASH_REMATCH[1]}"
    else
        DATA=$(date +"%Y%m%d")
    fi
    
    OUTPUT_FILE="centro_sportivo_ripristino_${DATA}.csv"
    
    echo ""
    echo "Ripristino in corso..."
    
    # Estrae il backup (tar -xzf estrae, -O manda su stdout, > salva in file)
    tar -xzf "$BACKUP_SCELTO" -O > "$OUTPUT_FILE" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Ripristino OK!${NC}"
        echo ""
        echo "File: $OUTPUT_FILE"
        echo "Righe: $(wc -l < "$OUTPUT_FILE")"
        echo "Dimensione: $(du -h "$OUTPUT_FILE" | cut -f1)"
        echo ""
        echo "NOTA: L'originale non è stato toccato!"
        echo "Per sostituire: cp $OUTPUT_FILE centro_sportivo.csv"
    else
        echo -e "${RED}✗ Errore durante ripristino${NC}"
    fi
    
    echo ""
    read -p "Premi Invio..."
}

# 4. Cerca utente
cerca_utente() {
    echo ""
    echo "========================================"
    echo "  CERCA UTENTE NEL BACKUP"
    echo "========================================"
    echo ""
    
    BACKUPS=($(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null))
    
    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo -e "${YELLOW}Nessun backup${NC}"
        read -p "Premi Invio..."
        return
    fi
    
    echo "Backup disponibili:"
    for i in "${!BACKUPS[@]}"; do
        FILENAME=$(basename "${BACKUPS[$i]}")
        if [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8})_([0-9]{6})\.tar\.gz ]]; then
            DATA="${BASH_REMATCH[1]}"
            ORA="${BASH_REMATCH[2]}"
            echo "$((i+1)). ${DATA:6:2}/${DATA:4:2}/${DATA:0:4} alle ${ORA:0:2}:${ORA:2:2}"
        fi
    done
    
    echo ""
    echo -n "Quale backup? [1-${#BACKUPS[@]}] (0=annulla): "
    read SCELTA_BACKUP
    
    if [ "$SCELTA_BACKUP" == "0" ]; then return; fi
    if [ "$SCELTA_BACKUP" -lt 1 ] || [ "$SCELTA_BACKUP" -gt ${#BACKUPS[@]} ]; then
        echo -e "${RED}Scelta non valida${NC}"
        read -p "Premi Invio..."
        return
    fi
    
    BACKUP_SCELTO="${BACKUPS[$((SCELTA_BACKUP-1))]}"
    
    echo ""
    echo "Cerca per: 1.ID  2.Nome  3.Cognome  4.Email  5.Sport"
    echo -n "Scegli [1-5]: "
    read TIPO_RICERCA
    
    echo -n "Valore: "
    read VALORE
    
    echo "Cerco..."
    
    # CSV usa ; come separatore
    HEADER=$(tar -xzf "$BACKUP_SCELTO" -O | head -n 1)
    
    # awk cerca nelle colonne (1=ID, 2=Nome, 3=Cognome, 5=Email, 6=Sport)
    case $TIPO_RICERCA in
        1) RISULTATI=$(tar -xzf "$BACKUP_SCELTO" -O | awk -F';' -v val="$VALORE" 'NR>1 && $1==val {print}') ;;
        2) RISULTATI=$(tar -xzf "$BACKUP_SCELTO" -O | awk -F';' -v val="$VALORE" 'NR>1 && $2==val {print}') ;;
        3) RISULTATI=$(tar -xzf "$BACKUP_SCELTO" -O | awk -F';' -v val="$VALORE" 'NR>1 && $3==val {print}') ;;
        4) RISULTATI=$(tar -xzf "$BACKUP_SCELTO" -O | awk -F';' -v val="$VALORE" 'NR>1 && $5==val {print}') ;;
        5) RISULTATI=$(tar -xzf "$BACKUP_SCELTO" -O | awk -F';' -v val="$VALORE" 'NR>1 && $6==val {print}') ;;
        *)
            echo -e "${RED}Scelta non valida${NC}"
            read -p "Premi Invio..."
            return
            ;;
    esac
    
    if [ -z "$RISULTATI" ]; then
        echo -e "${YELLOW}Nessun risultato${NC}"
        read -p "Premi Invio..."
        return
    fi
    
    NUM_RISULTATI=$(echo "$RISULTATI" | wc -l)
    FILENAME=$(basename "$BACKUP_SCELTO")
    [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8})_([0-9]{6})\.tar\.gz ]] && DATA="${BASH_REMATCH[1]}" || DATA=$(date +"%Y%m%d")
    
    if [ "$NUM_RISULTATI" -eq 1 ]; then
        # 1 utente trovato
        OUTPUT_FILE="utente_ripristinato_${DATA}.csv"
        echo "$HEADER" > "$OUTPUT_FILE"
        echo "$RISULTATI" >> "$OUTPUT_FILE"
        
        echo -e "${GREEN}✓ Trovato!${NC}"
        echo ""
        echo "$RISULTATI" | awk -F';' '{
            print "ID:      " $1
            print "Nome:    " $2 " " $3
            print "Email:   " $5
            print "Sport:   " $6
        }'
        echo ""
        echo "Salvato: $OUTPUT_FILE"
    else
        # Più utenti trovati
        OUTPUT_FILE="utenti_trovati_${DATA}.csv"
        
        echo -e "${GREEN}✓ Trovati $NUM_RISULTATI utenti:${NC}"
        echo ""
        echo "$RISULTATI" | awk -F';' '{printf "%s | %s %s | %s | %s\n", $1, $2, $3, $5, $6}' | nl
        
        echo "$HEADER" > "$OUTPUT_FILE"
        echo "$RISULTATI" >> "$OUTPUT_FILE"
        echo ""
        echo "Salvati: $OUTPUT_FILE"
    fi
    
    echo ""
    read -p "Premi Invio..."
}

# Loop menu principale
while true; do
    mostra_menu
    read SCELTA
    
    case $SCELTA in
        1) crea_backup ;;
        2) vedi_backup ;;
        3) ripristino_completo ;;
        4) cerca_utente ;;
        5) echo ""; echo "Ciao!"; exit 0 ;;
        *) echo ""; echo -e "${RED}Scelta non valida${NC}"; sleep 1 ;;
    esac
done
