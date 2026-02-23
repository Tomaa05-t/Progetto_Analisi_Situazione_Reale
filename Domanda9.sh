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
OUTPUT_DIR="analisi_ssh"
BLOCKED_FILE="ip_bloccati.txt"

# le soglie decidono quanto è pericoloso un IP
SOGLIA_BLOCCO=5    # sopra 5 tentativi lo blocco automaticamente
SOGLIA_ALTA=10     # sopra 10 = pericolo alto
SOGLIA_MEDIA=5     # tra 5 e 10 = pericolo medio
SOGLIA_BASSA=2     # tra 2 e 5 = pericolo basso

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# se chiamo lo script con "sblocca" entro in questa modalità
if [ "$1" = "sblocca" ]; then
    # serve sudo per usare iptables
    [ "$EUID" -ne 0 ] && echo "Errore: serve sudo" && exit 1
    [ ! -f "$BLOCKED_FILE" ] && echo "Nessun IP bloccato" && exit 0

    if [ "$2" = "tutti" ]; then
        # Conta quanti IP devo sbloccare
        TOTALE=$(wc -l < "$BLOCKED_FILE")
        
        echo "🔓 Sblocco IP in corso..."
        echo ""
        
        # sblocco tutti gli IP nel file
        # awk estrae la colonna 2 (l'IP nel nuovo formato)
        awk '{print $2}' "$BLOCKED_FILE" | while read IP; do
            if [ -n "$IP" ]; then
                iptables -D INPUT -s "$IP" -j DROP 2>/dev/null
                echo "✓ Sbloccato: $IP"
            fi
        done
        > "$BLOCKED_FILE"  # svuoto il file
        echo ""
        echo "✅ Tutti gli IP sbloccati ($TOTALE totali)"
    elif [ -n "$2" ]; then
        # sblocco solo l'IP specifico passato come parametro
        # grep -q cerca in silenzio (quiet), ritorna 0 se trova, 1 se non trova
        if grep -q "$2" "$BLOCKED_FILE"; then
            # iptables -D cancella la regola (D = Delete)
            iptables -D INPUT -s "$2" -j DROP 2>/dev/null
            # grep -v esclude le righe che contengono l'IP (v = inVert match)
            grep -v "$2" "$BLOCKED_FILE" > "$BLOCKED_FILE.tmp" && mv "$BLOCKED_FILE.tmp" "$BLOCKED_FILE"
            echo "✓ Sbloccato: $2"
        else
            echo "❌ IP $2 non trovato nella lista"
        fi
    else
        # se non specifico cosa sbloccare, mostro la lista
        echo "Uso: sudo ./Domanda9.sh sblocca [IP|tutti]"
        echo ""
        echo "IP attualmente bloccati:"
        # cat stampa il contenuto del file a schermo
        if [ -s "$BLOCKED_FILE" ]; then
            cat "$BLOCKED_FILE" | nl
        else
            echo "  Nessun IP bloccato"
        fi
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

# Verifica se posso usare iptables
POSSO_BLOCCARE=false
if [ "$EUID" -eq 0 ] && command -v iptables >/dev/null 2>&1; then
    POSSO_BLOCCARE=true
fi

echo "🔧 Debug: POSSO_BLOCCARE=$POSSO_BLOCCARE"
echo "🔧 Debug: Sono root? EUID=$EUID"
echo "🔧 Debug: iptables disponibile? $(command -v iptables)"
echo ""

# blocco automaticamente gli IP che superano la soglia
# >= invece di > perché voglio bloccare DA 5 in su, non da 6
awk -v s="$SOGLIA_BLOCCO" '$1 >= s {print $2}' "$TMP/ip_count.txt" > "$TMP/da_bloccare.txt"
echo "🔧 Debug: IP da bloccare (soglia >=$SOGLIA_BLOCCO):"
cat "$TMP/da_bloccare.txt"
echo ""
BLOCCATI_ORA=0

# Scrivo sempre nel file ip_bloccati.txt, anche se non posso usare iptables
if [ -s "$TMP/da_bloccare.txt" ]; then
    touch "$BLOCKED_FILE"
    while read IP; do
        TENTATIVI=$(grep " $IP$" "$TMP/ip_count.txt" | awk '{print $1}')
        
        # Se posso usare iptables, blocco anche nel firewall
        if [ "$POSSO_BLOCCARE" = true ]; then
            # Controllo se l'ho già bloccato prima
            if ! iptables -L INPUT -n | grep -q "$IP"; then
                iptables -A INPUT -s "$IP" -j DROP 2>/dev/null
                echo "🔒 Bloccato con iptables: $IP ($TENTATIVI tentativi)"
            fi
        else
            echo "📝 Registrato (iptables non disponibile): $IP ($TENTATIVI tentativi)"
        fi
        
        # Salvo sempre nel file per tracciare
        echo "$(date '+%Y-%m-%d %H:%M:%S') $IP $TENTATIVI tentativi" >> "$BLOCKED_FILE"
        BLOCCATI_ORA=$((BLOCCATI_ORA + 1))
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
    
    echo "IP BLOCCATI AUTOMATICAMENTE (≥$SOGLIA_BLOCCO tentativi)"
    echo "───────────────────────────────────────────────────────"
    if [ -s "$TMP/da_bloccare.txt" ]; then
        cat "$TMP/da_bloccare.txt"
        echo ""
        if [ "$POSSO_BLOCCARE" = false ]; then
            echo "💡 Per bloccare questi IP nel tuo firewall, usa:"
            echo "   sudo iptables -A INPUT -s [IP] -j DROP"
        fi
    else
        echo "Nessuno"
    fi
    echo ""
    
    echo "ULTIMI 20 TENTATIVI FALLITI"
    echo "───────────────────────────────────────────────────────"
    tail -20 "$TMP/falliti.log"
    
} > "$OUTPUT_FILE"

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

if [ "$BLOCCATI_ORA" -gt 0 ]; then
    echo ""
    echo -e "${RED}🔒 IP bloccati in questa esecuzione: $BLOCCATI_ORA${NC}"
fi

echo ""

if [ -s "$TMP/da_bloccare.txt" ]; then
    echo -e "${YELLOW}⚠️  IP che superano soglia di blocco ($SOGLIA_BLOCCO tentativi):${NC}"
    cat "$TMP/da_bloccare.txt" | sed 's/^/   - /'
    echo ""
fi

echo -e "${GREEN}📄 Report completo:${NC} $OUTPUT_FILE"
echo ""

# Cleanup
rm -rf "$TMP"

echo -e "${GREEN}✓ Script terminato con successo!${NC}"