#!/bin/bash
# Domanda8.sh - Backup database centro sportivo con menu interattivo
# Funziona sia da terminale che da Streamlit

# Gestisce i backup del file CSV con menu interattivo e modalità automatica

# Uso: ./Domanda8.sh         apre il menu
#      ./Domanda8.sh backup   crea backup (per Streamlit/cron)
#      ./Domanda8.sh list     elenca backup
#      ./Domanda8.sh stats    mostra statistiche

# Per configurare cron su Codespaces:
#   sudo apt-get install -y cron && sudo service cron start
#   crontab -e
#   Aggiungi: 0 22 * * * cd /workspaces/Progetto_Analisi_Situazione_Reale && ./Domanda8.sh backup

# file e cartelle che uso in tutto lo script
CSV_FILE="centro_sportivo.csv"
BACKUP_DIR="./backups"
LOG_DIR="./logs_backup"

# colori per rendere l'output più leggibile
RED='\033[0;31m'      # rosso per errori
GREEN='\033[0;32m'    # verde per successi
YELLOW='\033[1;33m'   # giallo per avvisi
BLUE='\033[0;34m'     # blu per informazioni
NC='\033[0m'          # no color, resetta il colore

# funzione che scrive un messaggio nel log con timestamp davanti
# esempio: [2026-02-18 15:30:45] Backup creato
log() { 
    mkdir -p "$LOG_DIR"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_DIR/backup_auto.log"
}

# FUNZIONE: crea_backup
# fa un backup manuale quando scelgo l'opzione 1 dal menu
# oppure viene chiamata con ./Domanda8.sh backup
crea_backup() {
    # controllo che il CSV esista
    if [ ! -f "$CSV_FILE" ]; then
        echo -e "${RED}Errore: $CSV_FILE non trovato${NC}"
        return 1
    fi

    # creo il timestamp per il nome del file backup
    # esempio: 20260218_153045
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    mkdir -p "$BACKUP_DIR" "$LOG_DIR"
    
    echo "📦 Creazione backup in corso..."
    
    # creo il backup compresso
    # tar -c crea l'archivio, -z lo comprime con gzip, -f specifica il nome
    # 2>/dev/null nasconde eventuali messaggi di errore
    tar -czf "$BACKUP_DIR/centro_sportivo_backup_${TIMESTAMP}.tar.gz" "$CSV_FILE" 2>/dev/null

    # controllo se il backup è andato bene
    # $? contiene il risultato dell'ultimo comando (0 = successo)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Backup creato: centro_sportivo_backup_${TIMESTAMP}.tar.gz${NC}"
        log "Backup creato OK"
        
        # rotazione backup: tengo solo gli ultimi 7
        # ls -t ordina per data (più recenti prima)
        # tail -n +8 prende dall'ottavo in poi (i vecchi)
        # xargs rm -f li cancella tutti
        ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null | tail -n +8 | xargs rm -f 2>/dev/null
        
        return 0
    else
        echo -e "${RED}✗ Errore durante il backup${NC}"
        log "Errore durante il backup"
        return 1
    fi
}

# FUNZIONE: vedi_backup
# mostra la lista di tutti i backup disponibili con data, ora e dimensione
vedi_backup() {
    # metto tutti i backup in un array ordinati per data (più recenti prima)
    BACKUPS=($(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null))

    # controllo se ci sono backup
    # ${#BACKUPS[@]} = numero di elementi nell'array
    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠️  Nessun backup trovato${NC}"
        return 1
    fi

    echo ""
    echo "📋 BACKUP DISPONIBILI:"
    echo "════════════════════════════════════════"
    
    # ciclo su tutti i backup
    # ${!BACKUPS[@]} = lista degli indici dell'array (0, 1, 2, ...)
    for i in "${!BACKUPS[@]}"; do
        FILENAME=$(basename "${BACKUPS[$i]}")
        SIZE=$(du -h "${BACKUPS[$i]}" | cut -f1)
        
        # uso regex per estrarre data e ora dal nome del file
        # nome: centro_sportivo_backup_20260218_153045.tar.gz
        # BASH_REMATCH[1] contiene la data, BASH_REMATCH[2] contiene l'ora
        if [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8})_([0-9]{6})\.tar\.gz ]]; then
            DATA="${BASH_REMATCH[1]}"
            ORA="${BASH_REMATCH[2]}"
            
            # estraggo le singole parti della data usando substring
            # ${DATA:6:2} prende 2 caratteri dalla posizione 6 (il giorno)
            # esempio: DATA=20260218 → ${DATA:6:2}=18
            echo "  $((i+1)). ${DATA:6:2}/${DATA:4:2}/${DATA:0:4} alle ${ORA:0:2}:${ORA:2:2} - $SIZE"
        fi
    done
    
    echo "════════════════════════════════════════"
    return 0
}

# FUNZIONE: ripristina_backup
# ripristina l'intero database da un backup
# IMPORTANTE: non sovrascrive mai l'originale, crea sempre un file nuovo
ripristina_backup() {
    BACKUPS=($(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null))

    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠️  Nessun backup disponibile${NC}"
        return 1
    fi

    echo ""
    echo "📋 BACKUP DISPONIBILI:"
    
    # mostro tutti i backup disponibili
    for i in "${!BACKUPS[@]}"; do
        FILENAME=$(basename "${BACKUPS[$i]}")
        if [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8})_([0-9]{6})\.tar\.gz ]]; then
            DATA="${BASH_REMATCH[1]}"
            ORA="${BASH_REMATCH[2]}"
            echo "  $((i+1)). ${DATA:6:2}/${DATA:4:2}/${DATA:0:4} alle ${ORA:0:2}:${ORA:2:2}"
        fi
    done

    read -p "Quale backup? (0=annulla): " SCELTA
    
    # controllo che la scelta sia valida
    if [ "$SCELTA" == "0" ] || [ "$SCELTA" -lt 1 ] || [ "$SCELTA" -gt ${#BACKUPS[@]} ]; then
        echo "Operazione annullata"
        return 1
    fi

    # prendo il backup scelto
    # l'array parte da 0 ma mostro i numeri da 1, quindi sottraggo 1
    BACKUP_SCELTO="${BACKUPS[$((SCELTA-1))]}"
    FILENAME=$(basename "$BACKUP_SCELTO")
    
    # estraggo la data dal nome per usarla nel file di output
    if [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8}) ]]; then
        DATA="${BASH_REMATCH[1]}"
    else
        DATA=$(date +"%Y%m%d")
    fi
    
    OUTPUT_FILE="centro_sportivo_ripristino_${DATA}.csv"

    echo "📥 Estrazione backup..."
    
    # estraggo il backup
    # tar -xzf estrae, -O manda su stdout invece che su disco
    # con > lo salvo nel file che voglio
    # questo evita di sovrascrivere accidentalmente l'originale
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

# FUNZIONE: cerca_utente
# cerca un utente specifico all'interno di un backup
# si può cercare per: ID, Nome, Cognome, Email o Sport
cerca_utente() {
    BACKUPS=($(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null))
    
    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠️  Nessun backup disponibile${NC}"
        return 1
    fi

    echo ""
    echo "📋 BACKUP DISPONIBILI:"
    
    # mostro i backup disponibili
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
    # Uso un file temporaneo perché è più sicuro e gestibile di una variabile
    TMP_CSV="/tmp/backup_search_$$.csv"
    tar -xzf "$BACKUP_SCELTO" -O > "$TMP_CSV" 2>/dev/null
    
    # Controllo che l'estrazione sia andata a buon fine
    if [ ! -f "$TMP_CSV" ] || [ ! -s "$TMP_CSV" ]; then
        echo -e "${RED}Errore nell'estrazione del backup${NC}"
        rm -f "$TMP_CSV"
        return 1
    fi

    # salvo l'header per ricrearlo nel file di output
    HEADER=$(head -n 1 "$TMP_CSV")
    
    if [ -z "$HEADER" ]; then
        echo -e "${RED}Errore: header vuoto${NC}"
        rm -f "$TMP_CSV"
        return 1
    fi

    # uso awk per cercare nel backup
    # -F';' usa il punto e virgola come separatore (il CSV usa ;)
    # -v v="$VALORE" passa il valore cercato ad awk
    # NR>1 salta l'header (Number of Record > 1)
    # $N==v confronta la colonna N con il valore cercato
    RISULTATI=""
    case $TIPO in
        1) RISULTATI=$(awk -F';' -v v="$VALORE" 'NR>1 && $1==v {print}' "$TMP_CSV") ;;  # ID
        2) RISULTATI=$(awk -F';' -v v="$VALORE" 'NR>1 && $2==v {print}' "$TMP_CSV") ;;  # Nome
        3) RISULTATI=$(awk -F';' -v v="$VALORE" 'NR>1 && $3==v {print}' "$TMP_CSV") ;;  # Cognome
        4) RISULTATI=$(awk -F';' -v v="$VALORE" 'NR>1 && $5==v {print}' "$TMP_CSV") ;;  # Email
        5) RISULTATI=$(awk -F';' -v v="$VALORE" 'NR>1 && $6==v {print}' "$TMP_CSV") ;;  # Sport
        *) echo -e "${RED}Scelta non valida${NC}"; rm -f "$TMP_CSV"; return 1 ;;
    esac

    # controllo se ho trovato qualcosa
    if [ -z "$RISULTATI" ]; then
        echo -e "${YELLOW}❌ Nessun risultato trovato per '$VALORE'${NC}"
        rm -f "$TMP_CSV"
        return 1
    fi

    [[ "$BACKUP_SCELTO" =~ centro_sportivo_backup_([0-9]{8}) ]] && DATA="${BASH_REMATCH[1]}" || DATA=$(date +"%Y%m%d")
    
    # conto quanti utenti ho trovato
    NUM=$(echo "$RISULTATI" | wc -l)

    # se trovo un solo utente mostro i dettagli in formato leggibile
    # se ne trovo più di uno li mostro tutti in lista numerata
    if [ "$NUM" -eq 1 ]; then
        OUTPUT_FILE="utente_ripristinato_${DATA}.csv"
        echo "$HEADER" > "$OUTPUT_FILE"
        echo "$RISULTATI" >> "$OUTPUT_FILE"
        
        echo -e "${GREEN}✓ Trovato!${NC}"
        echo ""
        # awk formatta i dati in modo leggibile
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
        # awk formatta e numera automaticamente con NR
        echo "$RISULTATI" | awk -F';' '{printf "%2d. %s | %s %s | %s\n", NR, $1, $2, $3, $5}'
    fi
    
    echo ""
    echo "📄 Salvati in: $OUTPUT_FILE"
    
    # Cleanup: rimuovo il file temporaneo
    rm -f "$TMP_CSV"
    return 0
}

# FUNZIONE: statistiche
# mostra statistiche sui backup: numero, dimensione totale, ultimo backup
statistiche() {
    BACKUPS=($(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null))
    
    echo ""
    echo "📊 STATISTICHE BACKUP:"
    echo "════════════════════════════════════════"
    echo "Numero di backup: ${#BACKUPS[@]}"
    
    if [ ${#BACKUPS[@]} -gt 0 ]; then
        # du -ch calcola la dimensione totale, tail -1 prende l'ultima riga (il totale)
        TOTAL_SIZE=$(du -ch "$BACKUP_DIR"/*.tar.gz 2>/dev/null | tail -1 | cut -f1)
        echo "Spazio totale: $TOTAL_SIZE"
        
        # mostro info sull'ultimo backup (il più recente)
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
    
    # mostro le ultime 5 righe del log
    if [ -f "$LOG_DIR/backup_auto.log" ]; then
        # sed 's/^/  /' aggiunge 2 spazi all'inizio di ogni riga (indentazione)
        tail -5 "$LOG_DIR/backup_auto.log" | sed 's/^/  /'
    else
        echo "  Nessun log disponibile"
    fi
    
    return 0
}

# MENU PRINCIPALE
# ciclo infinito che mostra il menu e aspetta la scelta dell'utente
# si esce solo scegliendo l'opzione 6
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

        # case/esac è come uno switch in altri linguaggi
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

# Controlla che il CSV esista prima di iniziare
if [ ! -f "$CSV_FILE" ]; then
    echo -e "${RED}Errore: $CSV_FILE non trovato${NC}"
    exit 1
fi

# Se eseguito con parametri, esegui l'azione (per Streamlit o automazione)
# Altrimenti mostra il menu interattivo
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