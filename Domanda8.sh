#!/bin/bash
################################################################################
# Domanda8.sh - Backup del database centro sportivo
# Alessandro - Febbraio 2026
#
# Cosa fa:
#   Gestisce i backup del file CSV con menu semplice.
#   Può anche fare backup automatici con cron.
#
# Come usare:
#   ./Domanda8.sh        -> apre il menu
#   ./Domanda8.sh auto   -> fa backup e basta (per cron)
#
################################################################################
# COME CONFIGURARE BACKUP AUTOMATICI CON CRON
################################################################################
#
# Cron è il sistema di Linux per schedulare script automatici.
# Serve un sistema Linux vero (non funziona su Codespaces di default).
#
# ============================================================================
# INSTALLAZIONE CRON SU CODESPACES (da rifare ogni riavvio)
# ============================================================================
#
# Codespaces non ha cron installato, quindi va installato ogni volta:
#
# 1. Installa cron:
#    sudo apt-get update
#    sudo apt-get install -y cron
#
# 2. Avvia il servizio:
#    sudo service cron start
#
# 3. Verifica che sia partito:
#    sudo service cron status
#    (deve dire "cron is running")
#
# ============================================================================
# CONFIGURAZIONE CRON
# ============================================================================
#
# 1. Apri crontab:
#    crontab -e
#
# 2. Se è la prima volta, scegli l'editor:
#    Scegli 1 (nano) - è il più semplice
#
# 3. Vai alla fine del file e aggiungi questa riga:
#    0 22 * * * cd /workspaces/Progetto_Analisi_Situazione_Reale && ./Domanda8.sh auto
#
#    Spiegazione:
#    0     = minuto 0
#    22    = ore 22 (10 di sera)
#    *     = ogni giorno del mese
#    *     = ogni mese
#    *     = ogni giorno della settimana
#
#    Quindi: "Esegui alle 22:00 di ogni giorno"
#
# 4. Salva il file:
#    - Premi Ctrl+O (per salvare)
#    - Premi Invio (per confermare)
#    - Premi Ctrl+X (per uscire)
#
# 5. Verifica che sia salvato:
#    crontab -l
#    (deve mostrare la riga che hai aggiunto)
#
# ============================================================================
# ALTRI ESEMPI DI SCHEDULAZIONE
# ============================================================================
#
# Ogni notte alle 3:00
#   0 3 * * * cd /path && ./Domanda8.sh auto
#
# Ogni 6 ore
#   0 */6 * * * cd /path && ./Domanda8.sh auto
#
# Ogni lunedì a mezzogiorno
#   0 12 * * 1 cd /path && ./Domanda8.sh auto
#
# Ogni giorno feriale alle 18:30
#   30 18 * * 1-5 cd /path && ./Domanda8.sh auto
#
# ============================================================================
# CONTROLLARE SE FUNZIONA
# ============================================================================
#
# Vedere i log dei backup:
#   cat logs_backup/backup_auto.log
#
# Vedere se cron sta girando:
#   sudo service cron status
#
# Vedere i job cron attivi:
#   crontab -l
#
################################################################################

################################################################################
# MODALITÀ AUTOMATICA
# 
# Questa sezione viene eseguita quando chiamo: ./Domanda8.sh auto
# È la parte che cron chiama automaticamente alle 22:00
#
# COME FUNZIONA:
#   1. Controlla che il CSV esista
#   2. Crea le cartelle backup e log se non ci sono
#   3. Comprime il CSV con tar.gz
#   4. Salva con timestamp nel nome
#   5. Elimina backup vecchi (tiene solo ultimi 7)
#   6. Scrive tutto nel log
################################################################################

if [ "$1" == "auto" ]; then
    
    #===========================================================================
    # CONFIGURAZIONE - Dove sono i file
    #===========================================================================
    
    CSV_FILE="centro_sportivo.csv"              # File database da backuppare
    BACKUP_DIR="./backups"                      # Cartella backup compressi
    LOG_DIR="./logs_backup"                     # Cartella log automatici
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")          # Es: 20260213_153045
    BACKUP_FILE="centro_sportivo_backup_${TIMESTAMP}.tar.gz"
    LOG_FILE="$LOG_DIR/backup_auto.log"         # Log principale
    
    #===========================================================================
    # FUNZIONE LOG - Scrive messaggi con data e ora
    #===========================================================================
    # Uso: log "messaggio da scrivere"
    # Output nel file: [2026-02-13 15:30:45] messaggio da scrivere
    
    log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    }
    
    #===========================================================================
    # INIZIO PROCEDURA
    #===========================================================================
    
    log "===== INIZIO BACKUP ====="
    
    #===========================================================================
    # CONTROLLO FILE - Verifica che il CSV esista
    #===========================================================================
    # Se il file non c'è, non posso fare backup quindi esco con errore
    # exit 1 = uscita con errore (cron lo segna come fallito)
    
    if [ ! -f "$CSV_FILE" ]; then
        log "ERRORE: File $CSV_FILE non trovato"
        log "===== FINE (ERRORE) ====="
        log ""
        exit 1
    fi
    
    log "File da backuppare: $CSV_FILE"
    
    #===========================================================================
    # CREAZIONE CARTELLE
    #===========================================================================
    # mkdir -p crea la cartella solo se non esiste
    # Non da errore se esiste già
    
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$LOG_DIR"
    
    #===========================================================================
    # INFORMAZIONI FILE
    #===========================================================================
    # Leggo dimensione e numero righe del file originale
    # du -h = dimensione leggibile (es: 106K)
    # wc -l = conta le righe
    
    ORIG_SIZE=$(du -h "$CSV_FILE" | cut -f1)
    NUM_RIGHE=$(wc -l < "$CSV_FILE")
    log "Dimensione: $ORIG_SIZE - Righe: $NUM_RIGHE"
    
    #===========================================================================
    # CREAZIONE BACKUP
    #===========================================================================
    # tar = comando per creare archivi
    # -c = crea nuovo archivio
    # -z = comprimi con gzip (riduce ~75% dimensione)
    # -f = specifica nome file output
    # 2>/dev/null = nasconde messaggi di errore
    
    log "Creo il backup..."
    tar -czf "$BACKUP_DIR/$BACKUP_FILE" "$CSV_FILE" 2>/dev/null
    
    #===========================================================================
    # VERIFICA SUCCESSO
    #===========================================================================
    # $? = codice uscita ultimo comando
    # 0 = successo, altro = errore
    
    if [ $? -eq 0 ]; then
        # Backup riuscito!
        
        BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
        log "OK! Backup creato: $BACKUP_FILE ($BACKUP_SIZE)"
        
        #=======================================================================
        # ROTAZIONE BACKUP - Elimina i vecchi
        #=======================================================================
        # Conta quanti backup esistono
        # Se sono più di 7, elimina i più vecchi
        # Così non riempio il disco
        
        NUM_BACKUPS=$(ls -1 "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null | wc -l)
        log "Backup totali: $NUM_BACKUPS"
        
        if [ "$NUM_BACKUPS" -gt 7 ]; then
            log "Elimino i backup vecchi (tengo solo gli ultimi 7)"
            
            # Come funziona:
            # ls -t = lista ordinata per data (più recenti prima)
            # tail -n +8 = prende dall'8° in poi (i vecchi)
            # xargs rm -f = elimina i file trovati
            
            ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz | tail -n +8 | xargs rm -f
            
            DOPO=$(ls -1 "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null | wc -l)
            log "Backup rimasti: $DOPO"
        fi
        
        #=======================================================================
        # LOG GIORNALIERO
        #=======================================================================
        # Oltre al log principale, salvo anche un log per ogni giorno
        # Così posso vedere facilmente i backup di oggi
        
        DATA_OGGI=$(date +"%Y-%m-%d")
        DAILY_LOG="$LOG_DIR/backup_${DATA_OGGI}.log"
        echo "Backup: $(date '+%H:%M:%S') - $BACKUP_FILE - $BACKUP_SIZE" >> "$DAILY_LOG"
        
        log "===== FINE BACKUP (OK) ====="
        log ""
        exit 0
        
    else
        # Backup fallito!
        
        log "ERRORE: Backup fallito!"
        log "===== FINE (ERRORE) ====="
        log ""
        exit 1
    fi
fi

################################################################################
# DA QUI IN POI: MODALITÀ INTERATTIVA (MENU)
# 
# Questa parte viene eseguita solo se NON passo il parametro "auto"
# Mostra un menu con 5 opzioni:
#   1. Crea backup manuale
#   2. Vedi lista backup
#   3. Ripristina tutto il database
#   4. Cerca un utente specifico
#   5. Esci
################################################################################

################################################################################
# CONFIGURAZIONE COLORI - Per output colorato
################################################################################
# Uso: echo -e "${GREEN}Testo verde${NC}"
# Il ${NC} alla fine resetta il colore

RED='\033[0;31m'      # Rosso per errori
GREEN='\033[0;32m'    # Verde per successi
YELLOW='\033[1;33m'   # Giallo per avvisi
NC='\033[0m'          # No Color - resetta colore

################################################################################
# VARIABILI GLOBALI modalità interattiva
################################################################################

CSV_FILE="centro_sportivo.csv"
BACKUP_DIR="./backups"

################################################################################
# FUNZIONE: mostra_menu
# Pulisce lo schermo e mostra il menu principale
################################################################################

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

################################################################################
# FUNZIONE: crea_backup
# 
# COSA FA:
#   1. Controlla che il CSV esista
#   2. Genera nome backup con timestamp
#   3. Comprime il file con tar.gz
#   4. Elimina backup vecchi se sono più di 7
#
# STESSO PROCESSO della modalità auto, ma mostra output a schermo
################################################################################

crea_backup() {
    echo ""
    echo "========================================"
    echo "  CREAZIONE BACKUP"
    echo "========================================"
    echo ""
    
    # Controllo esistenza file
    if [ ! -f "$CSV_FILE" ]; then
        echo -e "${RED}Errore: File $CSV_FILE non trovato${NC}"
        read -p "Premi Invio..."
        return
    fi
    
    # Nome backup con timestamp
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="centro_sportivo_backup_${TIMESTAMP}.tar.gz"
    
    # Crea cartella se non esiste
    mkdir -p "$BACKUP_DIR"
    
    # Mostra info
    echo "File: $CSV_FILE"
    echo "Dimensione: $(du -h "$CSV_FILE" | cut -f1)"
    echo ""
    echo "Creo il backup..."
    
    # Comprime il file
    tar -czf "$BACKUP_DIR/$BACKUP_FILE" "$CSV_FILE" 2>/dev/null
    
    # Controlla risultato
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}OK! Backup creato${NC}"
        echo ""
        echo "File: $BACKUP_FILE"
        echo "Dimensione: $(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)"
        
        # Rotazione backup
        NUM_BACKUPS=$(ls -1 "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null | wc -l)
        
        if [ "$NUM_BACKUPS" -gt 7 ]; then
            echo ""
            echo "Elimino i backup vecchi..."
            ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz | tail -n +8 | xargs rm -f
            echo "Fatto"
        fi
    else
        echo -e "${RED}Errore durante la creazione${NC}"
    fi
    
    echo ""
    read -p "Premi Invio..."
}

################################################################################
# FUNZIONE: vedi_backup
#
# COSA FA:
#   1. Cerca tutti i file .tar.gz nella cartella backups
#   2. Li ordina per data (più recenti prima)
#   3. Per ogni backup mostra: numero, data, ora, dimensione
#   4. Estrae data e ora dal nome file usando regex
################################################################################

vedi_backup() {
    echo ""
    echo "========================================"
    echo "  BACKUP DISPONIBILI"
    echo "========================================"
    echo ""
    
    # Crea array con tutti i backup
    # ls -t ordina per tempo modificato (più recenti prima)
    BACKUPS=($(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null))
    
    # Controlla se ci sono backup
    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo -e "${YELLOW}Nessun backup trovato${NC}"
        echo ""
        read -p "Premi Invio..."
        return
    fi
    
    # Cicla su ogni backup
    # ${!BACKUPS[@]} = indici dell'array (0, 1, 2, ...)
    for i in "${!BACKUPS[@]}"; do
        FILENAME=$(basename "${BACKUPS[$i]}")
        SIZE=$(du -h "${BACKUPS[$i]}" | cut -f1)
        
        # Regex per estrarre data e ora dal nome
        # Nome: centro_sportivo_backup_20260213_153045.tar.gz
        # Estrae: 20260213 (data) e 153045 (ora)
        if [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8})_([0-9]{6})\.tar\.gz ]]; then
            DATA="${BASH_REMATCH[1]}"     # 20260213
            ORA="${BASH_REMATCH[2]}"      # 153045
            
            # Estrae singole parti
            GIORNO="${DATA:6:2}"          # 13
            MESE="${DATA:4:2}"            # 02
            ANNO="${DATA:0:4}"            # 2026
            ORE="${ORA:0:2}"              # 15
            MINUTI="${ORA:2:2}"           # 30
            
            # Mostra in formato leggibile
            echo "$((i+1)). $GIORNO/$MESE/$ANNO alle $ORE:$MINUTI - $SIZE"
        else
            # Se il nome non segue il formato standard
            echo "$((i+1)). $FILENAME - $SIZE"
        fi
    done
    
    echo ""
    read -p "Premi Invio..."
}

################################################################################
# FUNZIONE: ripristino_completo
#
# SCOPO:
#   Ripristina l'intero database da un backup precedente
#
# COME FUNZIONA:
#   1. Mostra tutti i backup disponibili in ordine (più recenti prima)
#   2. L'utente sceglie quale backup ripristinare
#   3. Estrae il contenuto del backup .tar.gz
#   4. Salva in un NUOVO file chiamato: centro_sportivo_ripristino_DATA.csv
#   5. NON tocca il file originale (per sicurezza)
#
# PERCHÉ NON SOVRASCRIVE L'ORIGINALE:
#   - Se faccio un errore, non perdo il database attuale
#   - Posso confrontare il backup con l'originale prima di sostituirlo
#   - Più sicuro: devo fare un comando esplicito per sostituire
#
# ESEMPIO D'USO:
#   1. Scelgo backup del 13/02/2026
#   2. Lo script crea: centro_sportivo_ripristino_20260213.csv
#   3. Controllo che sia giusto: cat centro_sportivo_ripristino_20260213.csv
#   4. Se ok, sostituisco: cp centro_sportivo_ripristino_20260213.csv centro_sportivo.csv
#
################################################################################

ripristino_completo() {
    echo ""
    echo "========================================"
    echo "  RIPRISTINO COMPLETO"
    echo "========================================"
    echo ""
    
    #===========================================================================
    # PASSO 1: Prendo la lista di tutti i backup
    #===========================================================================
    # ls -t ordina per data di modifica (più recenti prima)
    # 2>/dev/null nasconde errori se la cartella è vuota
    # Il risultato va in un array BACKUPS
    
    BACKUPS=($(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null))
    
    #===========================================================================
    # PASSO 2: Controllo se ci sono backup
    #===========================================================================
    # ${#BACKUPS[@]} = numero elementi nell'array
    # Se è 0, non ci sono backup quindi esco
    
    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo -e "${YELLOW}Nessun backup disponibile${NC}"
        echo ""
        echo "Devi prima creare un backup con l'opzione 1"
        read -p "Premi Invio..."
        return
    fi
    
    echo "Backup disponibili:"
    echo ""
    
    #===========================================================================
    # PASSO 3: Mostro tutti i backup numerati
    #===========================================================================
    # Ciclo su ogni backup nell'array
    # ${!BACKUPS[@]} = lista degli indici (0, 1, 2, ...)
    
    for i in "${!BACKUPS[@]}"; do
        # basename toglie il percorso, lascia solo il nome file
        FILENAME=$(basename "${BACKUPS[$i]}")
        
        #=======================================================================
        # ESTRAZIONE DATA E ORA DAL NOME FILE
        #=======================================================================
        # Il nome file è: centro_sportivo_backup_20260213_153045.tar.gz
        # Voglio estrarre: 20260213 (data) e 153045 (ora)
        #
        # Uso regex (espressione regolare):
        # [0-9]{8} = 8 cifre (la data)
        # [0-9]{6} = 6 cifre (l'ora)
        # \. = punto letterale (devo escaparlo)
        #
        # =~ = operatore di match regex in bash
        # BASH_REMATCH[1] = primo gruppo catturato (data)
        # BASH_REMATCH[2] = secondo gruppo catturato (ora)
        
        if [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8})_([0-9]{6})\.tar\.gz ]]; then
            DATA="${BASH_REMATCH[1]}"     # Es: 20260213
            ORA="${BASH_REMATCH[2]}"      # Es: 153045
            
            #===================================================================
            # ESTRAZIONE SINGOLE PARTI DELLA DATA
            #===================================================================
            # ${DATA:6:2} significa:
            # - Prendi dalla variabile DATA
            # - Parti dalla posizione 6 (0-indexed)
            # - Prendi 2 caratteri
            #
            # Esempio con DATA=20260213:
            # Posizioni: 0 1 2 3 4 5 6 7
            # Caratteri: 2 0 2 6 0 2 1 3
            #
            # ${DATA:0:4} = 2026 (anno)
            # ${DATA:4:2} = 02 (mese)
            # ${DATA:6:2} = 13 (giorno)
            
            GIORNO="${DATA:6:2}"          # 13
            MESE="${DATA:4:2}"            # 02
            ANNO="${DATA:0:4}"            # 2026
            
            # Stessa cosa per l'ora
            ORE="${ORA:0:2}"              # 15
            MINUTI="${ORA:2:2}"           # 30
            
            # Mostro in formato leggibile: 13/02/2026 alle 15:30
            # $((i+1)) incrementa i di 1 (così parte da 1 invece che da 0)
            echo "$((i+1)). $GIORNO/$MESE/$ANNO alle $ORE:$MINUTI"
        else
            # Se il nome non segue il formato, lo mostro così
            echo "$((i+1)). $FILENAME"
        fi
    done
    
    echo ""
    echo -n "Quale backup vuoi ripristinare? [1-${#BACKUPS[@]}] (0 = annulla): "
    read SCELTA
    
    #===========================================================================
    # PASSO 4: Gestisco la scelta dell'utente
    #===========================================================================
    
    # Se sceglie 0, torno al menu senza fare nulla
    if [ "$SCELTA" == "0" ]; then
        return
    fi
    
    # Controllo che la scelta sia valida (tra 1 e numero backup)
    # -lt = less than (minore di)
    # -gt = greater than (maggiore di)
    if [ "$SCELTA" -lt 1 ] || [ "$SCELTA" -gt ${#BACKUPS[@]} ]; then
        echo -e "${RED}Scelta non valida${NC}"
        read -p "Premi Invio..."
        return
    fi
    
    #===========================================================================
    # PASSO 5: Prendo il backup scelto
    #===========================================================================
    # L'array parte da 0, ma l'utente vede numeri da 1
    # Quindi se l'utente sceglie 1, voglio l'elemento 0 dell'array
    # Per questo faccio SCELTA-1
    
    BACKUP_SCELTO="${BACKUPS[$((SCELTA-1))]}"
    FILENAME=$(basename "$BACKUP_SCELTO")
    
    #===========================================================================
    # PASSO 6: Genero il nome del file di output
    #===========================================================================
    # Voglio chiamare il file: centro_sportivo_ripristino_20260213.csv
    # Estraggo la data dal nome del backup
    
    if [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8})_([0-9]{6})\.tar\.gz ]]; then
        DATA="${BASH_REMATCH[1]}"     # 20260213
    else
        # Se non riesco a estrarre la data, uso quella di oggi
        DATA=$(date +"%Y%m%d")
    fi
    
    OUTPUT_FILE="centro_sportivo_ripristino_domanda8/centro_sportivo_ripristino_${DATA}.csv"
    
    echo ""
    echo "Ripristino in corso..."
    echo ""
    
    #===========================================================================
    # PASSO 7: ESTRAZIONE DEL BACKUP (PARTE CRUCIALE)
    #===========================================================================
    # Questo è il comando che fa il vero lavoro di ripristino
    #
    # tar -xzf BACKUP_FILE -O > OUTPUT_FILE
    #
    # Spiegazione dettagliata:
    #
    # tar = comando per gestire archivi
    # -x = extract (estrai)
    # -z = decomprimi con gzip (il backup è compresso)
    # -f = file (specifica quale file aprire)
    # -O = output su stdout invece che su disco
    #      (normalmente tar estrae su file, -O manda tutto sulla console)
    # > OUTPUT_FILE = redirige lo stdout nel file OUTPUT_FILE
    #
    # 2>/dev/null = nasconde messaggi di errore
    #
    # COSA SUCCEDE IN PRATICA:
    # 1. tar apre il file backup.tar.gz
    # 2. Lo decomprime
    # 3. Estrae il contenuto (che è il CSV)
    # 4. Invece di salvarlo su disco con il nome originale,
    #    lo manda su stdout (-O)
    # 5. Lo stdout viene rediretto (>) nel file OUTPUT_FILE
    #
    # PERCHÉ FACCIO COSÌ:
    # Se non usassi -O, tar estrarrebbe il file con il nome originale
    # (centro_sportivo.csv) e SOVRASCRIVEREBBE l'originale.
    # Usando -O > nuovo_nome, salvo con un nome diverso.
    
    tar -xzf "$BACKUP_SCELTO" -O > "$OUTPUT_FILE" 2>/dev/null
    
    #===========================================================================
    # PASSO 8: Verifico che l'estrazione sia andata bene
    #===========================================================================
    # $? = codice di uscita dell'ultimo comando
    # 0 = successo
    # qualsiasi altro numero = errore
    
    if [ $? -eq 0 ]; then
        # Estrazione riuscita!
        
        echo -e "${GREEN}✓ Ripristino completato con successo!${NC}"
        echo ""
        echo "Dettagli file ripristinato:"
        echo "  Nome file: $OUTPUT_FILE"
        
        # wc -l conta le righe
        # < redirige il file come input
        echo "  Numero righe: $(wc -l < "$OUTPUT_FILE")"
        
        # du -h mostra dimensione leggibile
        # cut -f1 prende solo il primo campo (la dimensione)
        echo "  Dimensione: $(du -h "$OUTPUT_FILE" | cut -f1)"
        
        echo ""
        echo "========================================"
        echo "IMPORTANTE!"
        echo "========================================"
        echo ""
        echo "Il file originale NON è stato toccato."
        echo "Ho creato un nuovo file: $OUTPUT_FILE"
        echo ""
        echo "COSA PUOI FARE ORA:"
        echo ""
        echo "1. Controllare il file ripristinato:"
        echo "   head -10 $OUTPUT_FILE"
        echo ""
        echo "2. Confrontarlo con l'originale:"
        echo "   diff centro_sportivo.csv $OUTPUT_FILE"
        echo ""
        echo "3. Se è tutto ok, sostituire l'originale:"
        echo "   cp $OUTPUT_FILE centro_sportivo.csv"
        echo ""
        echo "4. Oppure fare un backup dell'originale prima:"
        echo "   mv centro_sportivo.csv centro_sportivo_OLD.csv"
        echo "   cp $OUTPUT_FILE centro_sportivo.csv"
        echo ""
        
    else
        # Estrazione fallita!
        
        echo -e "${RED}✗ ERRORE durante il ripristino!${NC}"
        echo ""
        echo "Possibili cause:"
        echo "  - File backup corrotto"
        echo "  - Spazio disco insufficiente"
        echo "  - Permessi insufficienti"
        echo ""
        echo "Controlla e riprova."
    fi
    
    echo ""
    read -p "Premi Invio per tornare al menu..."
}

################################################################################
# FUNZIONE: cerca_utente
#
# COSA FA:
#   1. Chiede quale backup usare
#   2. Chiede per quale campo cercare (ID, Nome, Cognome, Email, Sport)
#   3. Chiede il valore da cercare
#   4. Cerca nel backup usando awk
#   5. Se trova 1 utente: lo salva in utente_ripristinato_DATA.csv
#      Se trova più utenti: li salva tutti in utenti_trovati_DATA.csv
#
# NOTA TECNICA:
#   Il CSV usa ; (punto e virgola) come separatore
#   Quindi awk usa -F';' invece di -F','
#
# STRUTTURA CSV:
#   Colonna 1: ID
#   Colonna 2: Nome
#   Colonna 3: Cognome
#   Colonna 4: Data_Nascita
#   Colonna 5: Email
#   Colonna 6: Sport
#   Colonna 7: Abbonamento
#   ...altre colonne...
################################################################################

cerca_utente() {
    echo ""
    echo "========================================"
    echo "  CERCA UTENTE NEL BACKUP"
    echo "========================================"
    echo ""
    
    # Prende lista backup
    BACKUPS=($(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null))
    
    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo -e "${YELLOW}Nessun backup disponibile${NC}"
        echo ""
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
            
            GIORNO="${DATA:6:2}"
            MESE="${DATA:4:2}"
            ANNO="${DATA:0:4}"
            ORE="${ORA:0:2}"
            MINUTI="${ORA:2:2}"
            
            echo "$((i+1)). $GIORNO/$MESE/$ANNO alle $ORE:$MINUTI"
        fi
    done
    
    echo ""
    echo -n "Quale backup? [1-${#BACKUPS[@]}] (0 = annulla): "
    read SCELTA_BACKUP
    
    if [ "$SCELTA_BACKUP" == "0" ]; then
        return
    fi
    
    if [ "$SCELTA_BACKUP" -lt 1 ] || [ "$SCELTA_BACKUP" -gt ${#BACKUPS[@]} ]; then
        echo -e "${RED}Scelta non valida${NC}"
        read -p "Premi Invio..."
        return
    fi
    
    BACKUP_SCELTO="${BACKUPS[$((SCELTA_BACKUP-1))]}"
    
    # Menu tipo ricerca
    echo ""
    echo "Cerca per:"
    echo "1. ID"
    echo "2. Nome"
    echo "3. Cognome"
    echo "4. Email"
    echo "5. Sport (piscina/palestra/tennis)"
    echo ""
    echo -n "Scegli [1-5]: "
    read TIPO_RICERCA
    
    echo ""
    echo -n "Valore da cercare: "
    read VALORE
    
    echo ""
    echo "Cerco..."
    echo ""
    
    #===========================================================================
    # ESTRAZIONE E RICERCA
    #===========================================================================
    # Il CSV usa ; come separatore (non ,)
    # Estraggo prima l'header (prima riga)
    
    HEADER=$(tar -xzf "$BACKUP_SCELTO" -O | head -n 1)
    
    #===========================================================================
    # RICERCA CON AWK
    #===========================================================================
    # awk è un linguaggio per processare file di testo
    # -F';' = usa ; come separatore di campo
    # -v val="$VALORE" = passa la variabile VALORE ad awk
    # NR>1 = salta la prima riga (Number of Record > 1)
    # $N == val = confronta colonna N con il valore cercato
    # {print} = stampa la riga se corrisponde
    
    case $TIPO_RICERCA in
        1)
            # Cerca per ID (colonna 1)
            RISULTATI=$(tar -xzf "$BACKUP_SCELTO" -O | awk -F';' -v val="$VALORE" 'NR>1 && $1==val {print}')
            ;;
        2)
            # Cerca per Nome (colonna 2)
            RISULTATI=$(tar -xzf "$BACKUP_SCELTO" -O | awk -F';' -v val="$VALORE" 'NR>1 && $2==val {print}')
            ;;
        3)
            # Cerca per Cognome (colonna 3)
            RISULTATI=$(tar -xzf "$BACKUP_SCELTO" -O | awk -F';' -v val="$VALORE" 'NR>1 && $3==val {print}')
            ;;
        4)
            # Cerca per Email (colonna 5)
            RISULTATI=$(tar -xzf "$BACKUP_SCELTO" -O | awk -F';' -v val="$VALORE" 'NR>1 && $5==val {print}')
            ;;
        5)
            # Cerca per Sport (colonna 6)
            RISULTATI=$(tar -xzf "$BACKUP_SCELTO" -O | awk -F';' -v val="$VALORE" 'NR>1 && $6==val {print}')
            ;;
        *)
            echo -e "${RED}Scelta non valida${NC}"
            read -p "Premi Invio..."
            return
            ;;
    esac
    
    # Controlla se ha trovato qualcosa
    if [ -z "$RISULTATI" ]; then
        echo -e "${YELLOW}Nessun risultato per: $VALORE${NC}"
        echo ""
        read -p "Premi Invio..."
        return
    fi
    
    # Conta quanti risultati
    NUM_RISULTATI=$(echo "$RISULTATI" | wc -l)
    
    #===========================================================================
    # CASO 1: TROVATO 1 SOLO UTENTE
    #===========================================================================
    
    if [ "$NUM_RISULTATI" -eq 1 ]; then
        # Estrae data dal nome backup
        FILENAME=$(basename "$BACKUP_SCELTO")
        if [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8})_([0-9]{6})\.tar\.gz ]]; then
            DATA="${BASH_REMATCH[1]}"
        else
            DATA=$(date +"%Y%m%d")
        fi
        
        OUTPUT_FILE="gestione_utenti_domanda8/utente_ripristinato_${DATA}.csv"
        
        # Crea file con header + utente trovato
        echo "$HEADER" > "$OUTPUT_FILE"
        echo "$RISULTATI" >> "$OUTPUT_FILE"
        
        echo -e "${GREEN}Trovato!${NC}"
        echo ""
        
        # Mostra dettagli in formato leggibile
        # awk -F';' usa ; come separatore
        # $1, $2, $3, etc. = colonne del CSV
        echo "$RISULTATI" | awk -F';' '{
            print "ID:      " $1
            print "Nome:    " $2 " " $3
            print "Email:   " $5
            print "Sport:   " $6
            print "Abbonam: " $7
        }'
        
        echo ""
        echo "Salvato in: $OUTPUT_FILE"
    
    #===========================================================================
    # CASO 2: TROVATI PIÙ UTENTI
    #===========================================================================
    
    else
        echo -e "${GREEN}Trovati $NUM_RISULTATI utenti:${NC}"
        echo ""
        
        # Mostra tutti in formato tabella
        # printf formatta l'output in colonne
        # nl numera le righe automaticamente
        echo "$RISULTATI" | awk -F';' '{
            printf "%s | %s %s | %s | %s\n", $1, $2, $3, $5, $6
        }' | nl
        
        # Salva tutti in un file
        FILENAME=$(basename "$BACKUP_SCELTO")
        if [[ "$FILENAME" =~ centro_sportivo_backup_([0-9]{8})_([0-9]{6})\.tar\.gz ]]; then
            DATA="${BASH_REMATCH[1]}"
        else
            DATA=$(date +"%Y%m%d")
        fi
        
        OUTPUT_FILE="gestione_utenti_domanda8/utenti_trovati_${DATA}.csv"
        
        echo "$HEADER" > "$OUTPUT_FILE"
        echo "$RISULTATI" >> "$OUTPUT_FILE"
        
        echo ""
        echo "Salvati tutti in: $OUTPUT_FILE"
    fi
    
    echo ""
    read -p "Premi Invio..."
}

################################################################################
# MAIN - Loop Menu Principale
# 
# Ciclo infinito che:
#   1. Mostra il menu
#   2. Legge la scelta dell'utente
#   3. Esegue la funzione corrispondente
#   4. Ripete all'infinito finché non si sceglie "5. Esci"
#
# COME FUNZIONA IL CASE:
#   case VARIABILE in
#       pattern1) comandi ;;
#       pattern2) comandi ;;
#       *) default ;;
#   esac
#
# * = qualsiasi altro valore (default)
################################################################################

while true; do
    # Mostra menu
    mostra_menu
    
    # Legge scelta utente
    read SCELTA
    
    # Esegue funzione in base alla scelta
    case $SCELTA in
        1)
            crea_backup
            ;;
        2)
            vedi_backup
            ;;
        3)
            ripristino_completo
            ;;
        4)
            cerca_utente
            ;;
        5)
            # Esce dal programma
            echo ""
            echo "Ciao!"
            exit 0
            ;;
        *)
            # Scelta non valida
            echo ""
            echo -e "${RED}Scelta non valida${NC}"
            sleep 1
            ;;
    esac
done


#   - Tutti i backup sono in ./backups/
#   - Tutti i log sono in ./logs_backup/
#   - Il CSV originale non viene mai sovrascritto
#   - Vengono mantenuti solo gli ultimi 7 backup
#   - Il delimitatore del CSV è ; (punto e virgola)
#
