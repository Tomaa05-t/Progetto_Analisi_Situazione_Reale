#!/bin/bash
# Domanda9.sh - Analisi attacchi SSH
# Alessandro - 2026
#
# Analizza auth.log e blocca automaticamente gli IP con troppi tentativi
#
# Uso:
#   sudo ./Domanda9.sh                 -> analizza e blocca
#   sudo ./Domanda9.sh sblocca 1.2.3.4 -> sblocca un IP
#   sudo ./Domanda9.sh sblocca tutti   -> sblocca tutti

AUTH_LOG="auth.log"
OUTPUT_FILE="analisi_ssh/analisi_ssh_$(date +"%Y%m%d_%H%M%S").txt"
BLOCKED_FILE="ip_bloccati.txt"
SOGLIA_BLOCCO=5
SOGLIA_ALTA=10
SOGLIA_MEDIA=5
SOGLIA_BASSA=2

# parte per sbloccare gli IP
if [ "$1" = "sblocca" ]; then
    [ "$EUID" -ne 0 ] && echo "Errore: serve sudo" && exit 1
    [ ! -f "$BLOCKED_FILE" ] && echo "Nessun IP bloccato" && exit 0

    if [ "$2" = "tutti" ]; then
        awk '{print $3}' "$BLOCKED_FILE" | while read IP; do
            iptables -D INPUT -s "$IP" -j DROP 2>/dev/null
            echo "Sbloccato: $IP"
        done
        > "$BLOCKED_FILE"
        echo "Tutti gli IP sbloccati"
    elif [ -n "$2" ]; then
        if grep -q "$2" "$BLOCKED_FILE"; then
            iptables -D INPUT -s "$2" -j DROP 2>/dev/null
            grep -v "$2" "$BLOCKED_FILE" > "$BLOCKED_FILE.tmp" && mv "$BLOCKED_FILE.tmp" "$BLOCKED_FILE"
            echo "Sbloccato: $2"
        else
            echo "IP non trovato nella lista"
        fi
    else
        echo "Uso: sudo ./Domanda9.sh sblocca [IP|tutti]"
        cat "$BLOCKED_FILE"
    fi
    exit 0
fi

[ ! -f "$AUTH_LOG" ] && echo "Errore: Non trovo $AUTH_LOG" && exit 1

# senza sudo posso solo analizzare
if [ "$EUID" -ne 0 ]; then
    echo "ATTENZIONE: Senza sudo posso solo analizzare"
    POSSO_BLOCCARE=false
else
    POSSO_BLOCCARE=true
fi

echo "Inizio l'analisi..."
TMP="/tmp/ssh_analisi_$$"
mkdir -p "$TMP" "analisi_ssh"

# cerco i tentativi falliti: password sbagliata, utente inesistente, connessione chiusa prima del login
grep -E "Failed password|Invalid user|Connection closed.*\[preauth\]|Disconnected.*\[preauth\]" \
    "$AUTH_LOG" > "$TMP/falliti.log"
NUM_FALLITI=$(wc -l < "$TMP/falliti.log")

# estraggo gli IP e conto i tentativi di ognuno
grep -oE "from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" "$TMP/falliti.log" | \
    awk '{print $2}' | sort | uniq -c | sort -rn > "$TMP/ip_count.txt"

# divido gli IP per livello di pericolo
awk -v s="$SOGLIA_ALTA" '$1 > s {printf "%-5d tentativi - IP: %s\n", $1, $2}' "$TMP/ip_count.txt" > "$TMP/alto.txt"
awk -v min="$SOGLIA_MEDIA" -v max="$SOGLIA_ALTA" '$1 >= min && $1 <= max {printf "%-5d tentativi - IP: %s\n", $1, $2}' "$TMP/ip_count.txt" > "$TMP/medio.txt"
awk -v min="$SOGLIA_BASSA" -v max="$SOGLIA_MEDIA" '$1 >= min && $1 < max {printf "%-5d tentativi - IP: %s\n", $1, $2}' "$TMP/ip_count.txt" > "$TMP/basso.txt"
NUM_ALTO=$(wc -l < "$TMP/alto.txt")
NUM_MEDIO=$(wc -l < "$TMP/medio.txt")
NUM_BASSO=$(wc -l < "$TMP/basso.txt")

# vedo quali utenti vengono attaccati più spesso
grep -oE "user [a-zA-Z0-9_-]+|for [a-zA-Z0-9_-]+ from" "$TMP/falliti.log" | \
    awk '{print $2}' | grep -v "^from$" | sort | uniq -c | sort -rn | head -10 > "$TMP/utenti.txt"

# blocco automaticamente chi supera la soglia
awk -v s="$SOGLIA_BLOCCO" '$1 > s {print $2}' "$TMP/ip_count.txt" > "$TMP/da_bloccare.txt"
BLOCCATI_ORA=0
if [ "$POSSO_BLOCCARE" = true ] && [ -s "$TMP/da_bloccare.txt" ]; then
    touch "$BLOCKED_FILE"
    while read IP; do
        if ! iptables -L INPUT -n | grep -q "$IP"; then
            TENTATIVI=$(grep " $IP$" "$TMP/ip_count.txt" | awk '{print $1}')
            iptables -A INPUT -s "$IP" -j DROP
            echo "$(date '+%Y-%m-%d %H:%M:%S') - $IP - $TENTATIVI tentativi" >> "$BLOCKED_FILE"
            echo "Bloccato: $IP ($TENTATIVI tentativi)"
            BLOCCATI_ORA=$((BLOCCATI_ORA + 1))
        fi
    done < "$TMP/da_bloccare.txt"
fi

# creo il report
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

rm -rf "$TMP"

echo ""
echo "Analisi completata! Report: $OUTPUT_FILE"
echo "ALTO: $NUM_ALTO IP  MEDIO: $NUM_MEDIO IP  BASSO: $NUM_BASSO IP"
[ "$BLOCCATI_ORA" -gt 0 ] && echo "Bloccati $BLOCCATI_ORA IP - lista in: $BLOCKED_FILE"
[ -s "$BLOCKED_FILE" ] && echo "Per sbloccare: sudo ./Domanda9.sh sblocca [IP|tutti]"
echo ""
