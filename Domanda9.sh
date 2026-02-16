#!/bin/bash
# Domanda9.sh - Analisi attacchi SSH
# Alessandro - 2026
#
# Script per analizzare i tentativi di login SSH falliti dal file auth.log
# Blocca automaticamente gli IP che fanno troppi tentativi (>5)
#
# Come si usa:
#   sudo ./Domanda9.sh                    -> analizza e blocca
#   sudo ./Domanda9.sh sblocca 1.2.3.4    -> sblocca un IP
#   sudo ./Domanda9.sh sblocca tutti      -> sblocca tutti gli IP

# File che uso
AUTH_LOG="auth.log"
OUTPUT_FILE="analisi_ssh_$(date +"%Y%m%d_%H%M%S").txt"
BLOCKED_FILE="ip_bloccati.txt"

# Ho deciso queste soglie guardando i log
SOGLIA_BLOCCO=5      # Sopra 5 tentativi è troppo, lo blocco
SOGLIA_ALTA=10       # Più di 10 = pericolo alto
SOGLIA_MEDIA=5       # Tra 5 e 10 = pericolo medio
SOGLIA_BASSA=2       # Tra 2 e 5 = pericolo basso

# Parte per sbloccare gli IP (se lo chiamo con "sblocca")
if [ "$1" = "sblocca" ]; then
    # Devo avere i permessi di root per usare iptables
    if [ "$EUID" -ne 0 ]; then
        echo "Errore: Devi usare sudo per sbloccare"
        exit 1
    fi
    
    # Controllo se ho effettivamente bloccato qualcuno
    if [ ! -f "$BLOCKED_FILE" ]; then
        echo "Non ho ancora bloccato nessun IP"
        exit 0
    fi
    
    # Sblocco tutti o solo uno specifico
    if [ "$2" = "tutti" ]; then
        # Leggo il file e sblocco tutti gli IP
        awk '{print $3}' "$BLOCKED_FILE" | while read IP; do
            iptables -D INPUT -s "$IP" -j DROP 2>/dev/null
            echo "Ho sbloccato: $IP"
        done
        > "$BLOCKED_FILE"
        echo "Fatto! Tutti gli IP sono stati sbloccati"
    elif [ -n "$2" ]; then
        # Sblocco solo l'IP che mi hanno detto
        IP="$2"
        if grep -q "$IP" "$BLOCKED_FILE"; then
            iptables -D INPUT -s "$IP" -j DROP 2>/dev/null
            grep -v "$IP" "$BLOCKED_FILE" > "$BLOCKED_FILE.tmp"
            mv "$BLOCKED_FILE.tmp" "$BLOCKED_FILE"
            echo "Ho sbloccato l'IP: $IP"
        else
            echo "Questo IP non era nella lista dei bloccati"
        fi
    else
        echo "Devi dirmi quale IP sbloccare!"
        echo "Uso: sudo ./Domanda9.sh sblocca [IP|tutti]"
        echo ""
        echo "IP che ho bloccato finora:"
        cat "$BLOCKED_FILE"
    fi
    exit 0
fi

# Parte principale - Analisi del log

# Controllo che il file esista
if [ ! -f "$AUTH_LOG" ]; then
    echo "Errore: Non trovo il file $AUTH_LOG"
    exit 1
fi

# Controllo se ho i permessi per bloccare
if [ "$EUID" -ne 0 ]; then
    echo "ATTENZIONE: Senza sudo posso solo analizzare, non bloccare"
    echo "Procedo comunque..."
    POSSO_BLOCCARE=false
else
    POSSO_BLOCCARE=true
fi

echo "Inizio l'analisi..."

# Creo una cartella temporanea per i file di lavoro
TMP="/tmp/ssh_analisi_$$"
mkdir -p "$TMP"

# Cerco tutti i tentativi falliti
# Questi sono i pattern che indicano un tentativo fallito:
# - "Failed password" = ha provato una password sbagliata
# - "Invalid user" = ha provato un utente che non esiste
# - "Connection closed [preauth]" = connessione chiusa prima di autenticarsi
# - "Disconnected [preauth]" = disconnesso prima di autenticarsi
grep -E "Failed password|Invalid user|Connection closed.*\[preauth\]|Disconnected.*\[preauth\]" \
    "$AUTH_LOG" > "$TMP/falliti.log"

NUM_FALLITI=$(wc -l < "$TMP/falliti.log")

# Conto quanti tentativi ha fatto ogni IP
# Estraggo gli IP dalle righe (hanno il pattern "from XXX.XXX.XXX.XXX")
# Poi li conto e li ordino dal più al meno
grep -oE "from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" "$TMP/falliti.log" | \
    awk '{print $2}' | \
    sort | \
    uniq -c | \
    sort -rn > "$TMP/ip_count.txt"

# Divido gli IP in categorie di pericolo
# ALTO: più di 10 tentativi (attacco serio)
awk -v soglia="$SOGLIA_ALTA" '$1 > soglia {printf "%-5d tentativi - IP: %s\n", $1, $2}' \
    "$TMP/ip_count.txt" > "$TMP/alto.txt"

# MEDIO: tra 5 e 10 tentativi (sospetto)
awk -v min="$SOGLIA_MEDIA" -v max="$SOGLIA_ALTA" \
    '$1 >= min && $1 <= max {printf "%-5d tentativi - IP: %s\n", $1, $2}' \
    "$TMP/ip_count.txt" > "$TMP/medio.txt"

# BASSO: tra 2 e 5 tentativi (magari si è sbagliato?)
awk -v min="$SOGLIA_BASSA" -v max="$SOGLIA_MEDIA" \
    '$1 >= min && $1 < max {printf "%-5d tentativi - IP: %s\n", $1, $2}' \
    "$TMP/ip_count.txt" > "$TMP/basso.txt"

NUM_ALTO=$(wc -l < "$TMP/alto.txt")
NUM_MEDIO=$(wc -l < "$TMP/medio.txt")
NUM_BASSO=$(wc -l < "$TMP/basso.txt")

# Top 10 utenti più attaccati
# Estraggo i nomi utente dai tentativi falliti e vedo quali provano più spesso
grep -oE "user [a-zA-Z0-9_-]+|for [a-zA-Z0-9_-]+ from" "$TMP/falliti.log" | \
    awk '{print $2}' | \
    grep -v "^from$" | \
    sort | \
    uniq -c | \
    sort -rn | \
    head -10 > "$TMP/utenti.txt"

# BLOCCO AUTOMATICO
# Prendo tutti gli IP con più di SOGLIA_BLOCCO tentativi
awk -v soglia="$SOGLIA_BLOCCO" '$1 > soglia {print $2}' "$TMP/ip_count.txt" > "$TMP/da_bloccare.txt"
NUM_DA_BLOCCARE=$(wc -l < "$TMP/da_bloccare.txt")

BLOCCATI_ORA=0

if [ "$POSSO_BLOCCARE" = true ] && [ "$NUM_DA_BLOCCARE" -gt 0 ]; then
    touch "$BLOCKED_FILE"
    
    # Blocco ogni IP nella lista
    while read IP; do
        # Controllo se l'ho già bloccato prima
        if ! iptables -L INPUT -n | grep -q "$IP"; then
            TENTATIVI=$(grep " $IP$" "$TMP/ip_count.txt" | awk '{print $1}')
            
            # Questo è il comando che blocca l'IP
            iptables -A INPUT -s "$IP" -j DROP
            
            # Salvo nel file per ricordarmi che l'ho bloccato
            echo "$(date '+%Y-%m-%d %H:%M:%S') - $IP - $TENTATIVI tentativi" >> "$BLOCKED_FILE"
            
            echo "Ho bloccato: $IP (aveva fatto $TENTATIVI tentativi)"
            BLOCCATI_ORA=$((BLOCCATI_ORA + 1))
        fi
    done < "$TMP/da_bloccare.txt"
fi

# Creo il file di report con tutti i dettagli
{
    echo "REPORT ANALISI TENTATIVI SSH"
    echo ""
    echo "Data analisi: $(date '+%d/%m/%Y alle %H:%M:%S')"
    echo "File analizzato: $AUTH_LOG"
    echo ""
    
    echo "RIEPILOGO"
    echo "---------"
    echo "Righe totali nel log:    $(wc -l < "$AUTH_LOG")"
    echo "Tentativi falliti:       $NUM_FALLITI"
    echo "Accessi riusciti:        $(grep -c "Accepted password" "$AUTH_LOG")"
    echo "IP bloccati adesso:      $BLOCCATI_ORA"
    echo ""
    
    echo "CLASSIFICAZIONE IP PER PERICOLO"
    echo "-------------------------------"
    echo "ALTO (>$SOGLIA_ALTA tentativi):      $NUM_ALTO IP"
    echo "MEDIO ($SOGLIA_MEDIA-$SOGLIA_ALTA tentativi):     $NUM_MEDIO IP"
    echo "BASSO ($SOGLIA_BASSA-$((SOGLIA_MEDIA-1)) tentativi):     $NUM_BASSO IP"
    echo ""
    
    echo "IP CON PERICOLO ALTO (più di $SOGLIA_ALTA tentativi)"
    echo "----------------------------------------------------"
    if [ "$NUM_ALTO" -gt 0 ]; then
        cat "$TMP/alto.txt"
    else
        echo "Nessuno (per fortuna!)"
    fi
    echo ""
    
    echo "IP CON PERICOLO MEDIO (da $SOGLIA_MEDIA a $SOGLIA_ALTA tentativi)"
    echo "---------------------------------------------------------"
    if [ "$NUM_MEDIO" -gt 0 ]; then
        cat "$TMP/medio.txt"
    else
        echo "Nessuno"
    fi
    echo ""
    
    echo "IP CON PERICOLO BASSO (da $SOGLIA_BASSA a $((SOGLIA_MEDIA-1)) tentativi)"
    echo "--------------------------------------------------------"
    if [ "$NUM_BASSO" -gt 0 ]; then
        cat "$TMP/basso.txt"
    else
        echo "Nessuno"
    fi
    echo ""
    
    echo "TOP 10 UTENTI PIÙ ATTACCATI"
    echo "---------------------------"
    cat "$TMP/utenti.txt"
    echo ""
    
    echo "LISTA COMPLETA TENTATIVI FALLITI (formato OpenSSH originale)"
    echo "------------------------------------------------------------"
    cat "$TMP/falliti.log"
    
} > "$OUTPUT_FILE"

# Cancello i file temporanei
rm -rf "$TMP"

# Mostro i risultati a schermo
echo ""
echo "Analisi completata!"
echo ""
echo "Ho salvato il report completo in: $OUTPUT_FILE"
echo ""
echo "RISULTATI:"
echo "  IP ad ALTO pericolo:   $NUM_ALTO"
echo "  IP a MEDIO pericolo:   $NUM_MEDIO"
echo "  IP a BASSO pericolo:   $NUM_BASSO"

if [ "$BLOCCATI_ORA" -gt 0 ]; then
    echo ""
    echo "Ho bloccato $BLOCCATI_ORA IP con più di $SOGLIA_BLOCCO tentativi"
    echo "La lista completa è in: $BLOCKED_FILE"
fi

# Se ho già bloccato IP in passato, spiego come sbloccarli
if [ -f "$BLOCKED_FILE" ] && [ -s "$BLOCKED_FILE" ]; then
    echo ""
    echo "Per sbloccare un IP:"
    echo "  sudo ./Domanda9.sh sblocca 203.0.113.45"
    echo ""
    echo "Per sbloccare tutti gli IP:"
    echo "  sudo ./Domanda9.sh sblocca tutti"
fi

echo ""
