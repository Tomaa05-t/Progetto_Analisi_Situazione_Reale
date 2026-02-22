#!/bin/bash
# Domanda8.sh - Backup database centro sportivo

# Gestisce i backup del file CSV con menu interattivo e modalità automatica

# Uso: ./Domanda8.sh         apre il menu
#      ./Domanda8.sh auto    backup automatico (per cron)

# Per configurare cron su Codespaces:
#   sudo apt-get install -y cron && sudo service cron start
#   crontab -e
#   Aggiungi: 0 22 * * * cd /workspaces/Progetto_Analisi_Situazione_Reale && ./Domanda8.sh auto
# Demo live
#./Domanda8.sh
# Scegli opzione 1 - crea backup
#ls -lh backups/

# file e cartelle che uso in tutto lo script
CSV_FILE="centro_sportivo.csv"
BACKUP_DIR="./backups"
LOG_DIR="./logs_backup"

# colori per rendere l'output più leggibile
RED='\033[0;31m'      # rosso per errori
GREEN='\033[0;32m'    # verde per successi
YELLOW='\033[1;33m'   # giallo per avvisi
NC='\033[0m'          # no color, resetta il colore

# funzione che scrive un messaggio nel log con timestamp davanti
# esempio: [2026-02-18 15:30:45] Backup creato
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_DIR/backup_auto.log"; }

# MODALITÀ AUTOMATICA
# viene eseguita quando chiamo: ./Domanda8.sh auto
# è quella che viene chiamata da cron ogni sera alle 22:00
if [ "$1" == "auto" ]; then
    # creo il timestamp per il nome del file backup
    # esempio: 20260218_153045
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    
    # creo le cartelle se non esistono
    mkdir -p "$BACKUP_DIR" "$LOG_DIR"
    log "Inizio backup..."

    # controllo che il CSV esista
    if [ ! -f "$CSV_FILE" ]; then
        log "Errore: $CSV_FILE non trovato"; exit 1
    fi

    ## creo il backup compresso
    # tar -c crea l'archivio, -z lo comprime con gzip, -f specifica il nome
    # 2>/dev/null nasconde eventuali messaggi di errore
    tar -czf "$BACKUP_DIR/centro_sportivo_backup_${TIMESTAMP}.tar.gz" "$CSV_FILE" 2>/dev/null

    # controllo se il backup è andato bene
    # $? contiene il risultato dell'ultimo comando (0 = successo)
    if [ $? -eq 0 ]; then
        log "Backup creato OK"
        
        # rotazione backup: tengo solo gli ultimi 7
        ## ls -t ordina per data (più recenti prima)
        # tail -n +8 prende dall'ottavo in poi (i vecchi)
        # xargs rm -f li cancella tutti
        ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null | tail -n +8 | xargs rm -f
        
        # scrivo anche un log giornaliero separato
        echo "$(date '+%H:%M:%S') - backup OK" >> "$LOG_DIR/backup_$(date +"%Y-%m-%d").log"
        log "Fine (OK)"; exit 0
    else
        log "Errore durante il backup!"; exit 1
    fi
fi

# FUNZIONE: crea_backup
# fa un backup manuale quando scelgo l'opzione 1 dal menu
crea_backup() {
    # controllo che il CSV esista
    if [ ! -f "$CSV_FILE" ]; then
        echo -e "${RED}Errore: $CSV_FILE non trovato${NC}"
        read -p "Premi Invio..."; return
    fi

    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    mkdir -p "$BACKUP_DIR"
    echo "Creo il backup..."

    # comprimo il file
    tar -czf "$BACKUP_DIR/centro_sportivo_backup_${TIMESTAMP}.tar.gz" "$CSV_FILE" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Backup creato!${NC}"
        # rotazione: se ho più di 7 backup cancello i più vecchi
        ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null | tail -n +8 | xargs rm -f
    else
        echo -e "${RED}Qualcosa è andato storto${NC}"
    fi
    read -p "Premi Invio..."
}

# FUNZIONE: vedi_backup
# mostra la lista di tutti i backup disponibili con data, ora e dimensione
vedi_backup() {
    # metto tutti i backup in un array ordinati per data (più recenti prima)
    BACKUPS=($(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null))

    # controllo se ci sono backup
    # ${#BACKUPS[@]} = numero di elementi nell'array
    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo -e "${YELLOW}Nessun backup trovato${NC}"
        read -p "Premi Invio..."; return
    fi

    # ciclo su tutti i backup
    # ${!BACKUPS[@]} = lista degli indici dell'array (0, 1, 2, ...)
    for i in "${!BACKUPS[@]}"; do
        FILENAME=$(basename "${BACKUPS[$i]}")
        
        # uso regex per estrarre data e ora dal nome del file
        # nome: centro_sportivo_backup_20260218_153045.tar.gz
        # BASH_REMATCH[1] contiene la data, BASH_REMATCH[2] contiene l'ora
        if [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8})_([0-9]{6})\.tar\.gz ]]; then
            DATA="${BASH_REMATCH[1]}"; ORA="${BASH_REMATCH[2]}"
            
            # estraggo le singole parti della data usando substring
            # ${DATA:6:2} prende 2 caratteri dalla posizione 6 (il giorno)
            # esempio: DATA=20260218 → ${DATA:6:2}=18
            echo "$((i+1)). ${DATA:6:2}/${DATA:4:2}/${DATA:0:4} alle ${ORA:0:2}:${ORA:2:2} - $(du -h "${BACKUPS[$i]}" | cut -f1)"
        fi
    done
    read -p "Premi Invio..."
}

# FUNZIONE: ripristino_completo
# ripristina l'intero database da un backup
# IMPORTANTE: non sovrascrive mai l'originale, crea sempre un file nuovo
ripristino_completo() {
    BACKUPS=($(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null))

    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo -e "${YELLOW}Nessun backup disponibile${NC}"
        read -p "Premi Invio..."; return
    fi

    # mostro tutti i backup disponibili
    for i in "${!BACKUPS[@]}"; do
        FILENAME=$(basename "${BACKUPS[$i]}")
        if [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8})_([0-9]{6})\.tar\.gz ]]; then
            DATA="${BASH_REMATCH[1]}"; ORA="${BASH_REMATCH[2]}"
            echo "$((i+1)). ${DATA:6:2}/${DATA:4:2}/${DATA:0:4} alle ${ORA:0:2}:${ORA:2:2}"
        fi
    done

    read -p "Quale backup? (0=annulla): " SCELTA
    [ "$SCELTA" == "0" ] && return
    
    # controllo che la scelta sia valida
    [ "$SCELTA" -lt 1 ] || [ "$SCELTA" -gt ${#BACKUPS[@]} ] && echo "Scelta non valida" && read -p "Premi Invio..." && return

    # prendo il backup scelto
    # l'array parte da 0 ma mostro i numeri da 1, quindi sottraggo 1
    BACKUP_SCELTO="${BACKUPS[$((SCELTA-1))]}"
    FILENAME=$(basename "$BACKUP_SCELTO")
    
    # estraggo la data dal nome per usarla nel file di output
    [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8}) ]] && DATA="${BASH_REMATCH[1]}" || DATA=$(date +"%Y%m%d")
    OUTPUT_FILE='centro_sportivo_ripristino_${DATA}.csv'

    # estraggo il backup
    # tar -xzf estrae, -O manda su stdout invece che su disco
    # con > lo salvo nel file che voglio
    # questo evita di sovrascrivere accidentalmente l'originale
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

# FUNZIONE: cerca_utente
# cerca un utente specifico all'interno di un backup
# si può cercare per: ID, Nome, Cognome, Email o Sport
cerca_utente() {
    BACKUPS=($(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null))
    [ ${#BACKUPS[@]} -eq 0 ] && echo "Nessun backup" && read -p "Premi Invio..." && return

    # mostro i backup disponibili
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

    # uso awk per cercare nel backup
    # -F';' usa il punto e virgola come separatore (il CSV usa ;)
    # -v v="$VALORE" passa il valore cercato ad awk
    # NR>1 salta l'header (Number of Record > 1)
    # $N==v confronta la colonna N con il valore cercato
    case $TIPO in
        1) RISULTATI=$(tar -xzf "$BACKUP_SCELTO" -O | awk -F';' -v v="$VALORE" 'NR>1 && $1==v') ;;  # ID
        2) RISULTATI=$(tar -xzf "$BACKUP_SCELTO" -O | awk -F';' -v v="$VALORE" 'NR>1 && $2==v') ;;  # Nome
        3) RISULTATI=$(tar -xzf "$BACKUP_SCELTO" -O | awk -F';' -v v="$VALORE" 'NR>1 && $3==v') ;;  # Cognome
        4) RISULTATI=$(tar -xzf "$BACKUP_SCELTO" -O | awk -F';' -v v="$VALORE" 'NR>1 && $5==v') ;;  # Email
        5) RISULTATI=$(tar -xzf "$BACKUP_SCELTO" -O | awk -F';' -v v="$VALORE" 'NR>1 && $6==v') ;;  # Sport
        *) echo "Scelta non valida"; read -p "Premi Invio..."; return ;;
    esac

    # controllo se ho trovato qualcosa
    [ -z "$RISULTATI" ] && echo -e "${YELLOW}Nessun risultato${NC}" && read -p "Premi Invio..." && return

    # conto quanti utenti ho trovato
    NUM=$(echo "$RISULTATI" | wc -l)
    [[ "$BACKUP_SCELTO" =~ centro_sportivo_backup_([0-9]{8}) ]] && DATA="${BASH_REMATCH[1]}" || DATA=$(date +"%Y%m%d")

    # se trovo un solo utente mostro i dettagli in formato leggibile
    # se ne trovo più di uno li mostro tutti in lista numerata
    if [ "$NUM" -eq 1 ]; then
        OUTPUT_FILE="utente_ripristinato_${DATA}.csv"
        echo "$HEADER" > "$OUTPUT_FILE"; echo "$RISULTATI" >> "$OUTPUT_FILE"
        echo -e "${GREEN}Trovato!${NC}"
        # awk formatta i dati in modo leggibile
        echo "$RISULTATI" | awk -F';' '{print "ID: "$1"\nNome: "$2" "$3"\nEmail: "$5"\nSport: "$6}'
    else
        OUTPUT_FILE="utenti_trovati_${DATA}.csv"
        echo "$HEADER" > "$OUTPUT_FILE"; echo "$RISULTATI" >> "$OUTPUT_FILE"
        echo -e "${GREEN}Trovati $NUM utenti${NC}"
        # nl numera automaticamente le righe
        echo "$RISULTATI" | awk -F';' '{printf "%s | %s %s | %s\n", $1, $2, $3, $5}' | nl
    fi
    echo "Salvati in: $OUTPUT_FILE"
    read -p "Premi Invio..."
}

# MENU PRINCIPALE
# ciclo infinito che mostra il menu e aspetta la scelta dell'utente
# si esce solo scegliendo l'opzione 5
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

    # case/esac è come uno switch in altri linguaggi
    case $SCELTA in
        1) crea_backup ;;
        2) vedi_backup ;;
        3) ripristino_completo ;;
        4) cerca_utente ;;
        5) echo "Ciao!"; exit 0 ;;
        *) echo -e "${RED}Scelta non valida${NC}"; sleep 1 ;;
    esac
done