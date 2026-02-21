#!/bin/bash
# Domanda9.sh - Analisi attacchi SSH
# Analizza auth.log e blocca automaticamente gli IP con troppi tentativi
# Uso:
#   sudo ./Domanda9.sh                 -> analizza e blocca
#   sudo ./Domanda9.sh sblocca 1.2.3.4 -> sblocca un IP
#   sudo ./Domanda9.sh sblocca tutti   -> sblocca tutti
# NOTA SU IPTABLES:
# iptables è il firewall di Linux che controlla il traffico di rete
# -A INPUT = Aggiungi regola alla catena INPUT (traffico in entrata)
# -D INPUT = Cancella regola dalla catena INPUT  
# -L INPUT = Lista le regole della catena INPUT
# -s IP    = specifica l'IP sorgente (source)
# -j DROP  = azione: DROP scarta i pacchetti senza rispondere
# -n       = mostra IP numerici invece di risolvere i nomi
AUTH_LOG="auth.log"
OUTPUT_FILE="analisi_ssh/analisi_ssh_$(date +"%Y%m%d_%H%M%S").txt"
BLOCKED_FILE="ip_bloccati.txt"

# le soglie decidono quanto è pericoloso un IP
SOGLIA_BLOCCO=5    # sopra 5 tentativi lo blocco automaticamente
SOGLIA_ALTA=10     # sopra 10 = pericolo alto
SOGLIA_MEDIA=5     # tra 5 e 10 = pericolo medio
SOGLIA_BASSA=2     # tra 2 e 5 = pericolo basso

# se chiamo lo script con "sblocca" entro in questa modalità
if [ "$1" = "sblocca" ]; then
    # serve sudo per usare iptables
    [ "$EUID" -ne 0 ] && echo "Errore: serve sudo" && exit 1
    [ ! -f "$BLOCKED_FILE" ] && echo "Nessun IP bloccato" && exit 0

    if [ "$2" = "tutti" ]; then
        # sblocco tutti gli IP nel file
        # awk estrae la colonna 3 (l'IP), poi per ognuno rimuovo la regola iptables
        awk '{print $3}' "$BLOCKED_FILE" | while read IP; do
            iptables -D INPUT -s "$IP" -j DROP 2>/dev/null
            echo "Sbloccato: $IP"
        done
        > "$BLOCKED_FILE"  # svuoto il file
        echo "Tutti gli IP sbloccati"
    elif [ -n "$2" ]; then
        # sblocco solo l'IP specifico passato come parametro
        # grep -q cerca in silenzio (quiet), ritorna 0 se trova, 1 se non trova
        if grep -q "$2" "$BLOCKED_FILE"; then
            # iptables -D cancella la regola (D = Delete)
            iptables -D INPUT -s "$2" -j DROP 2>/dev/null
            # grep -v esclude le righe che contengono l'IP (v = inVert match)
            grep -v "$2" "$BLOCKED_FILE" > "$BLOCKED_FILE.tmp" && mv "$BLOCKED_FILE.tmp" "$BLOCKED_FILE"
            echo "Sbloccato: $2"
        else
            echo "IP non trovato nella lista"
        fi
    else
        # se non specifico cosa sbloccare, mostro la lista
        echo "Uso: sudo ./Domanda9.sh sblocca [IP|tutti]"
        # cat stampa il contenuto del file a schermo
        cat "$BLOCKED_FILE"
    fi
    exit 0
fi

# controllo che il file auth.log esista
[ ! -f "$AUTH_LOG" ] && echo "Errore: Non trovo $AUTH_LOG" && exit 1

# controllo se ho i permessi per bloccare
if [ "$EUID" -ne 0 ]; then
    echo "ATTENZIONE: Senza sudo posso solo analizzare"
    POSSO_BLOCCARE=false
else
    POSSO_BLOCCARE=true
fi

echo "Inizio l'analisi..."
TMP="/tmp/ssh_analisi_$$"
# mkdir -p crea le cartelle, -p non da errore se esistono già
mkdir -p "$TMP" "analisi_ssh"

# cerco tutti i tentativi falliti nel log
# grep cerca questi pattern che indicano un tentativo di attacco:
# - Failed password = password sbagliata
# - Invalid user = utente che non esiste
# - Connection closed [preauth] = chiuso prima di autenticarsi
# - Disconnected [preauth] = disconnesso prima di autenticarsi
grep -E "Failed password|Invalid user|Connection closed.*\[preauth\]|Disconnected.*\[preauth\]" \
    "$AUTH_LOG" > "$TMP/falliti.log"
# wc -l conta le righe del file (l = Lines)
NUM_FALLITI=$(wc -l < "$TMP/falliti.log")

# estraggo gli IP dalle righe e conto quanti tentativi ha fatto ognuno
# grep -oE estrae solo il pattern "from XXX.XXX.XXX.XXX"
# awk stampa solo il secondo campo (l'IP)
# sort ordina gli IP alfabeticamente
# uniq -c conta quante volte appare ogni IP (c = Count)
# sort -rn ordina per numero (n = Numeric) al contrario (r = Reverse, dal più alto)
grep -oE "from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" "$TMP/falliti.log" | \
    awk '{print $2}' | sort | uniq -c | sort -rn > "$TMP/ip_count.txt"

# divido gli IP in tre categorie di pericolo
# awk confronta il numero di tentativi con le soglie e stampa solo quelli che rientrano
awk -v s="$SOGLIA_ALTA" '$1 > s {printf "%-5d tentativi - IP: %s\n", $1, $2}' \
    "$TMP/ip_count.txt" > "$TMP/alto.txt"

awk -v min="$SOGLIA_MEDIA" -v max="$SOGLIA_ALTA" \
    '$1 >= min && $1 <= max {printf "%-5d tentativi - IP: %s\n", $1, $2}' \
    "$TMP/ip_count.txt" > "$TMP/medio.txt"

awk -v min="$SOGLIA_BASSA" -v max="$SOGLIA_MEDIA" \
    '$1 >= min && $1 < max {printf "%-5d tentativi - IP: %s\n", $1, $2}' \
    "$TMP/ip_count.txt" > "$TMP/basso.txt"

NUM_ALTO=$(wc -l < "$TMP/alto.txt")
NUM_MEDIO=$(wc -l < "$TMP/medio.txt")
NUM_BASSO=$(wc -l < "$TMP/basso.txt")

# vedo quali nomi utente vengono provati più spesso dagli attaccanti
# grep cerca "user nome" o "for nome from"
# awk stampa il secondo campo (il nome utente)
# grep -v esclude la parola "from" (v = inVert)
# sort | uniq -c conta le occorrenze
# sort -rn ordina dal più alto
# head -10 prende solo i primi 10 (head = testa del file)
grep -oE "user [a-zA-Z0-9_-]+|for [a-zA-Z0-9_-]+ from" "$TMP/falliti.log" | \
    awk '{print $2}' | grep -v "^from$" | sort | uniq -c | sort -rn | head -10 > "$TMP/utenti.txt"

# blocco automaticamente gli IP che superano la soglia
awk -v s="$SOGLIA_BLOCCO" '$1 > s {print $2}' "$TMP/ip_count.txt" > "$TMP/da_bloccare.txt"
BLOCCATI_ORA=0

if [ "$POSSO_BLOCCARE" = true ] && [ -s "$TMP/da_bloccare.txt" ]; then
    touch "$BLOCKED_FILE"
    while read IP; do
        # iptables -L lista le regole, grep -q cerca in silenzio
        # controllo se l'ho già bloccato prima (così non lo blocco due volte)
        if ! iptables -L INPUT -n | grep -q "$IP"; then
            TENTATIVI=$(grep " $IP$" "$TMP/ip_count.txt" | awk '{print $1}')
            # iptables -A INPUT -s IP -j DROP = blocca tutto il traffico da quell'IP
            iptables -A INPUT -s "$IP" -j DROP
            # salvo nel file per ricordarmi chi ho bloccato
            echo "$(date '+%Y-%m-%d %H:%M:%S') - $IP - $TENTATIVI tentativi" >> "$BLOCKED_FILE"
            echo "Bloccato: $IP ($TENTATIVI tentativi)"
            BLOCCATI_ORA=$((BLOCCATI_ORA + 1))
        fi
    done < "$TMP/da_bloccare.txt"
fi

# creo il report con tutte le informazioni raccolte
{
    echo "REPORT ANALISI TENTATIVI SSH"
    echo "Data: $(date '+%d/%m/%Y alle %H:%M:%S') - File: $AUTH_LOG"
    echo ""
    echo "RIEPILOGO"
    echo "Righe totali:      $(wc -l < "$AUTH_LOG")"
    echo "Tentativi falliti: $NUM_FALLITI"
    echo "Accessi riusciti:  $(grep -c "Accepted password" "$AUTH_LOG")"
    echo "IP bloccati ora:   $BLOCCATI_ORA"
    echo ""
    echo "CLASSIFICAZIONE IP"
    echo "ALTO  (>$SOGLIA_ALTA tentativi):  $NUM_ALTO IP"
    echo "MEDIO ($SOGLIA_MEDIA-$SOGLIA_ALTA tentativi): $NUM_MEDIO IP"
    echo "BASSO ($SOGLIA_BASSA-$((SOGLIA_MEDIA-1)) tentativi): $NUM_BASSO IP"
    echo ""
    echo "IP PERICOLO ALTO"
    [ "$NUM_ALTO" -gt 0 ] && cat "$TMP/alto.txt" || echo "Nessuno"
    echo ""
    echo "IP PERICOLO MEDIO"
    [ "$NUM_MEDIO" -gt 0 ] && cat "$TMP/medio.txt" || echo "Nessuno"
    echo ""
    echo "IP PERICOLO BASSO"
    [ "$NUM_BASSO" -gt 0 ] && cat "$TMP/basso.txt" || echo "Nessuno"
    echo ""
    echo "TOP 10 UTENTI ATTACCATI"
    cat "$TMP/utenti.txt"
    echo ""
    echo "TUTTI I TENTATIVI FALLITI"
    cat "$TMP/falliti.log"
} > "$OUTPUT_FILE"

# cancello i file temporanei
rm -rf "$TMP"

echo ""
echo "Analisi completata! Report: $OUTPUT_FILE"
echo "ALTO: $NUM_ALTO IP  MEDIO: $NUM_MEDIO IP  BASSO: $NUM_BASSO IP"
[ "$BLOCCATI_ORA" -gt 0 ] && echo "Bloccati $BLOCCATI_ORA IP - lista in: $BLOCKED_FILE"
[ -s "$BLOCKED_FILE" ] && echo "Per sbloccare: sudo ./Domanda9.sh sblocca [IP|tutti]"
echo ""