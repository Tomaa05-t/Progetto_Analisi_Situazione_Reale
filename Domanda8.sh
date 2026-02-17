#!/bin/bash
# Domanda8.sh - Backup database centro sportivo
# Alessandro - 2026
#
# Uso: ./Domanda8.sh        -> apre il menu
#      ./Domanda8.sh auto   -> backup automatico (per cron)
#
# Per configurare cron su Codespaces:
#   sudo apt-get install -y cron && sudo service cron start
#   crontab -e
#   Aggiungi: 0 22 * * * cd /workspaces/Progetto_Analisi_Situazione_Reale && ./Domanda8.sh auto

# file e cartelle che uso in tutto lo script
CSV_FILE="centro_sportivo.csv"
BACKUP_DIR="./backups"
LOG_DIR="./logs_backup"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# scrive un messaggio nel log con data e ora davanti
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_DIR/backup_auto.log"; }

# MODALITÀ AUTO - chiamata da cron ogni sera alle 22:00
if [ "$1" == "auto" ]; then
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    mkdir -p "$BACKUP_DIR" "$LOG_DIR"
    log "Inizio backup..."

    if [ ! -f "$CSV_FILE" ]; then
        log "Errore: $CSV_FILE non trovato"; exit 1
    fi

    # creo il backup compresso, -czf = crea + gzip + nome file
    tar -czf "$BACKUP_DIR/centro_sportivo_backup_${TIMESTAMP}.tar.gz" "$CSV_FILE" 2>/dev/null

    if [ $? -eq 0 ]; then
        log "Backup creato OK"
        # tengo solo gli ultimi 7, cancello i più vecchi
        ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null | tail -n +8 | xargs rm -f
        echo "$(date '+%H:%M:%S') - backup OK" >> "$LOG_DIR/backup_$(date +"%Y-%m-%d").log"
        log "Fine (OK)"; exit 0
    else
        log "Errore durante il backup!"; exit 1
    fi
fi

# fa il backup manualmente dal menu
crea_backup() {
    if [ ! -f "$CSV_FILE" ]; then
        echo -e "${RED}Errore: $CSV_FILE non trovato${NC}"
        read -p "Premi Invio..."; return
    fi

    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    mkdir -p "$BACKUP_DIR"
    echo "Creo il backup..."

    tar -czf "$BACKUP_DIR/centro_sportivo_backup_${TIMESTAMP}.tar.gz" "$CSV_FILE" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Backup creato!${NC}"
        # se ho più di 7 backup cancello i più vecchi
        ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null | tail -n +8 | xargs rm -f
    else
        echo -e "${RED}Qualcosa è andato storto${NC}"
    fi
    read -p "Premi Invio..."
}

# mostra la lista dei backup disponibili
vedi_backup() {
    BACKUPS=($(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null))

    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo -e "${YELLOW}Nessun backup trovato${NC}"
        read -p "Premi Invio..."; return
    fi

    for i in "${!BACKUPS[@]}"; do
        FILENAME=$(basename "${BACKUPS[$i]}")
        # uso regex per estrarre data e ora dal nome del file
        # il nome è tipo: centro_sportivo_backup_20260213_153045.tar.gz
        if [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8})_([0-9]{6})\.tar\.gz ]]; then
            DATA="${BASH_REMATCH[1]}"; ORA="${BASH_REMATCH[2]}"
            # ${DATA:6:2} prende 2 caratteri dalla posizione 6 (il giorno)
            echo "$((i+1)). ${DATA:6:2}/${DATA:4:2}/${DATA:0:4} alle ${ORA:0:2}:${ORA:2:2} - $(du -h "${BACKUPS[$i]}" | cut -f1)"
        fi
    done
    read -p "Premi Invio..."
}

# ripristina il database da un backup scelto
# non sovrascrive mai l'originale, crea sempre un file nuovo
ripristino_completo() {
    BACKUPS=($(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null))

    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo -e "${YELLOW}Nessun backup disponibile${NC}"
        read -p "Premi Invio..."; return
    fi

    for i in "${!BACKUPS[@]}"; do
        FILENAME=$(basename "${BACKUPS[$i]}")
        if [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8})_([0-9]{6})\.tar\.gz ]]; then
            DATA="${BASH_REMATCH[1]}"; ORA="${BASH_REMATCH[2]}"
            echo "$((i+1)). ${DATA:6:2}/${DATA:4:2}/${DATA:0:4} alle ${ORA:0:2}:${ORA:2:2}"
        fi
    done

    read -p "Quale backup? (0=annulla): " SCELTA
    [ "$SCELTA" == "0" ] && return
    [ "$SCELTA" -lt 1 ] || [ "$SCELTA" -gt ${#BACKUPS[@]} ] && echo "Scelta non valida" && read -p "Premi Invio..." && return

    BACKUP_SCELTO="${BACKUPS[$((SCELTA-1))]}"
    FILENAME=$(basename "$BACKUP_SCELTO")
    [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8}) ]] && DATA="${BASH_REMATCH[1]}" || DATA=$(date +"%Y%m%d")
    OUTPUT_FILE="centro_sportivo_ripristino_${DATA}.csv"

    # tar -xzf estrae il backup, -O lo manda su stdout invece che su disco
    # con > lo salvo nel file che voglio, così non sovrascrivo l'originale
    tar -xzf "$BACKUP_SCELTO" -O > "$OUTPUT_FILE" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Ripristino riuscito!${NC}"
        echo "File creato: $OUTPUT_FILE ($(wc -l < "$OUTPUT_FILE") righe)"
        echo "Per sostituire l'originale: cp $OUTPUT_FILE $CSV_FILE"
    else
        echo -e "${RED}Qualcosa è andato storto${NC}"
    fi
    read -p "Premi Invio..."
}

# cerca un utente in un backup per ID, Nome, Cognome, Email o Sport
cerca_utente() {
    BACKUPS=($(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null))
    [ ${#BACKUPS[@]} -eq 0 ] && echo "Nessun backup" && read -p "Premi Invio..." && return

    for i in "${!BACKUPS[@]}"; do
        FILENAME=$(basename "${BACKUPS[$i]}")
        [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8})_([0-9]{6})\.tar\.gz ]] && \
        DATA="${BASH_REMATCH[1]}" && ORA="${BASH_REMATCH[2]}" && \
        echo "$((i+1)). ${DATA:6:2}/${DATA:4:2}/${DATA:0:4} alle ${ORA:0:2}:${ORA:2:2}"
    done

    read -p "Quale backup? (0=annulla): " SCELTA
    [ "$SCELTA" == "0" ] && return
    BACKUP_SCELTO="${BACKUPS[$((SCELTA-1))]}"

    echo "Cerca per: 1.ID  2.Nome  3.Cognome  4.Email  5.Sport"
    read -p "Scegli [1-5]: " TIPO
    read -p "Cosa cerchi? " VALORE

    # salvo l'header per ricrearlo nel file di output
    HEADER=$(tar -xzf "$BACKUP_SCELTO" -O | head -n 1)

    # awk cerca nel backup usando ; come separatore
    # NR>1 salta l'header, $N==v controlla la colonna giusta
    case $TIPO in
        1) RISULTATI=$(tar -xzf "$BACKUP_SCELTO" -O | awk -F';' -v v="$VALORE" 'NR>1 && $1==v') ;;
        2) RISULTATI=$(tar -xzf "$BACKUP_SCELTO" -O | awk -F';' -v v="$VALORE" 'NR>1 && $2==v') ;;
        3) RISULTATI=$(tar -xzf "$BACKUP_SCELTO" -O | awk -F';' -v v="$VALORE" 'NR>1 && $3==v') ;;
        4) RISULTATI=$(tar -xzf "$BACKUP_SCELTO" -O | awk -F';' -v v="$VALORE" 'NR>1 && $5==v') ;;
        5) RISULTATI=$(tar -xzf "$BACKUP_SCELTO" -O | awk -F';' -v v="$VALORE" 'NR>1 && $6==v') ;;
        *) echo "Scelta non valida"; read -p "Premi Invio..."; return ;;
    esac

    [ -z "$RISULTATI" ] && echo -e "${YELLOW}Nessun risultato${NC}" && read -p "Premi Invio..." && return

    NUM=$(echo "$RISULTATI" | wc -l)
    [[ "$BACKUP_SCELTO" =~ centro_sportivo_backup_([0-9]{8}) ]] && DATA="${BASH_REMATCH[1]}" || DATA=$(date +"%Y%m%d")

    # se trovo un solo utente mostro i dettagli, altrimenti li elenco tutti
    if [ "$NUM" -eq 1 ]; then
        OUTPUT_FILE="utente_ripristinato_${DATA}.csv"
        echo "$HEADER" > "$OUTPUT_FILE"; echo "$RISULTATI" >> "$OUTPUT_FILE"
        echo -e "${GREEN}Trovato!${NC}"
        echo "$RISULTATI" | awk -F';' '{print "ID: "$1"\nNome: "$2" "$3"\nEmail: "$5"\nSport: "$6}'
    else
        OUTPUT_FILE="utenti_trovati_${DATA}.csv"
        echo "$HEADER" > "$OUTPUT_FILE"; echo "$RISULTATI" >> "$OUTPUT_FILE"
        echo -e "${GREEN}Trovati $NUM utenti${NC}"
        echo "$RISULTATI" | awk -F';' '{printf "%s | %s %s | %s\n", $1, $2, $3, $5}' | nl
    fi
    echo "Salvati in: $OUTPUT_FILE"
    read -p "Premi Invio..."
}

# menu principale, gira in loop finché non si sceglie Esci
while true; do
    clear
    echo "  BACKUP DATABASE CENTRO SPORTIVO"
    echo ""
    echo "1. Crea backup"
    echo "2. Vedi backup disponibili"
    echo "3. Ripristina backup completo"
    echo "4. Cerca utente nel backup"
    echo "5. Esci"
    echo ""
    read -p "Scegli [1-5]: " SCELTA

    case $SCELTA in
        1) crea_backup ;;
        2) vedi_backup ;;
        3) ripristino_completo ;;
        4) cerca_utente ;;
        5) echo "Ciao!"; exit 0 ;;
        *) echo -e "${RED}Scelta non valida${NC}"; sleep 1 ;;
    esac
done
