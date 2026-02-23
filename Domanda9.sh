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
#Demo live
#sudo ./Domanda9.sh
#cat analisi_ssh/analisi_ssh_*.txt

AUTH_LOG="auth.log"
OUTPUT_DIR="analisi_ssh"
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

# Controlla se il file esiste
if [ ! -f "$AUTH_LOG" ]; then
    echo -e "${RED}Errore: $AUTH_LOG non trovato${NC}"
    exit 1
fi

echo "🔍 ANALISI ATTACCHI SSH"
echo "======================================"
echo ""

mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="$OUTPUT_DIR/analisi_ssh_$(date +"%Y%m%d_%H%M%S").txt"

TMP="/tmp/ssh_analisi_$$"
mkdir -p "$TMP"

# Estrai i tentativi falliti
echo "📊 Analizzando log..."
grep -E "Failed password|Invalid user|Connection closed.*\[preauth\]|Disconnected.*\[preauth\]" \
    "$AUTH_LOG" > "$TMP/falliti.log"

NUM_FALLITI=$(wc -l < "$TMP/falliti.log")

# Conta i tentativi per IP
grep -oE "from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" "$TMP/falliti.log" | \
    awk '{print $2}' | sort | uniq -c | sort -rn > "$TMP/ip_count.txt"

# Classifica per pericolo
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

# Top utenti attaccati
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
    echo "═══════════════════════════════════════════════════════"
    echo "Data: $(date '+%d/%m/%Y alle %H:%M:%S')"
    echo "File: $AUTH_LOG"
    echo ""
    
    echo "RIEPILOGO"
    echo "───────────────────────────────────────────────────────"
    echo "Righe totali:      $(wc -l < "$AUTH_LOG")"
    echo "Tentativi falliti: $NUM_FALLITI"
    echo "Accessi riusciti:  $(grep -c "Accepted password" "$AUTH_LOG" 2>/dev/null || echo 0)"
    echo ""
    
    echo "CLASSIFICAZIONE IP"
    echo "───────────────────────────────────────────────────────"
    echo "🔴 ALTO   (>$SOGLIA_ALTA tentativi):  $NUM_ALTO IP"
    echo "🟠 MEDIO  ($SOGLIA_MEDIA-$SOGLIA_ALTA tentativi): $NUM_MEDIO IP"
    echo "🟡 BASSO  ($SOGLIA_BASSA-$((SOGLIA_MEDIA-1)) tentativi): $NUM_BASSO IP"
    echo ""
    
    echo "IP PERICOLO ALTO (⚠️  ATTENZIONE!)"
    echo "───────────────────────────────────────────────────────"
    [ -s "$TMP/alto.txt" ] && cat "$TMP/alto.txt" || echo "Nessuno"
    echo ""
    
    echo "IP PERICOLO MEDIO (⚠️  MONITORARE)"
    echo "───────────────────────────────────────────────────────"
    [ -s "$TMP/medio.txt" ] && cat "$TMP/medio.txt" || echo "Nessuno"
    echo ""
    
    echo "IP PERICOLO BASSO (⚠️  OSSERVARE)"
    echo "───────────────────────────────────────────────────────"
    [ -s "$TMP/basso.txt" ] && cat "$TMP/basso.txt" || echo "Nessuno"
    echo ""
    
    echo "TOP 10 UTENTI ATTACCATI"
    echo "───────────────────────────────────────────────────────"
    cat "$TMP/utenti.txt"
    echo ""
    
    echo "IP CONSIGLIATI PER BLOCCO (≥$SOGLIA_BLOCCO tentativi)"
    echo "───────────────────────────────────────────────────────"
    if [ -s "$TMP/da_bloccare.txt" ]; then
        cat "$TMP/da_bloccare.txt"
        echo ""
        echo "💡 In Codespaces iptables non è disponibile."
        echo "   Per bloccare questi IP nel tuo firewall personale, usa:"
        echo "   sudo iptables -A INPUT -s [IP] -j DROP"
    else
        echo "Nessuno"
    fi
    echo ""
    
    echo "ULTIMI 20 TENTATIVI FALLITI"
    echo "───────────────────────────────────────────────────────"
    tail -20 "$TMP/falliti.log"
    
} > "$OUTPUT_FILE"

# Salva anche la lista di IP da bloccare
if [ -s "$TMP/da_bloccare.txt" ]; then
    cat "$TMP/da_bloccare.txt" > "$BLOCKED_FILE"
fi

# Mostra il riepilogo
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}ANALISI COMPLETATA${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "📊 Statistiche:"
echo "   Tentativi falliti: $NUM_FALLITI"
echo "   🔴 Pericolo ALTO:  $NUM_ALTO IP"
echo "   🟠 Pericolo MEDIO: $NUM_MEDIO IP"
echo "   🟡 Pericolo BASSO: $NUM_BASSO IP"
echo ""

if [ -s "$TMP/da_bloccare.txt" ]; then
    echo -e "${RED}⚠️  IP CONSIGLIATI PER BLOCCO:${NC}"
    cat "$TMP/da_bloccare.txt" | sed 's/^/   - /'
    echo ""
fi

echo -e "${GREEN}📄 Report completo:${NC} $OUTPUT_FILE"
echo ""

# Cleanup
rm -rf "$TMP"

echo -e "${GREEN}✓ Script terminato con successo!${NC}"