#!/bin/bash
# Domanda10.sh - Pulizia e Recupero Dati Corrotti
# Versione per Codespaces - Senza pipe complesse

INPUT_CSV="centro_sportivo.csv"
OUTPUT_CORROTTE="righe_corrotte.csv"
OUTPUT_PULITO="centro_sportivo_pulito.csv"
BACKUP_DIR="./backups"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Controlla che il CSV esista
if [ ! -f "$INPUT_CSV" ]; then
    echo -e "${RED}Errore: $INPUT_CSV non trovato${NC}"
    exit 1
fi

echo " PULIZIA E RECUPERO DATI (Domanda 10)"
echo "════════════════════════════════════════"
echo ""

# Prendi l'header e conta i campi
HEADER=$(head -n 1 "$INPUT_CSV")
NUM_CAMPI=$(echo "$HEADER" | awk -F';' '{print NF}')

echo " Analizzando CSV..."
echo "   Campi per riga: $NUM_CAMPI"
echo ""

# Inizializza i file di output
echo "$HEADER" > "$OUTPUT_CORROTTE"
echo "$HEADER" > "$OUTPUT_PULITO"

NUM_CORROTTE=0
NUM_PULITE=0

# Leggi il CSV e analizza riga per riga
tail -n +2 "$INPUT_CSV" | while IFS=';' read -r ID NOME COGNOME DATA EMAIL SPORT ABBONAMENTO SCADENZA ACCESSO; do
    
    # Controlla se la riga è completa
    CAMPI_RIGA=$(echo "$ID;$NOME;$COGNOME;$DATA;$EMAIL;$SPORT;$ABBONAMENTO;$SCADENZA;$ACCESSO" | awk -F';' '{print NF}')
    
    CORROTTA=false
    MOTIVO=""
    
    # Validazioni
    [ "$CAMPI_RIGA" -ne "$NUM_CAMPI" ] && CORROTTA=true && MOTIVO="Campi: $CAMPI_RIGA invece di $NUM_CAMPI"
    [ -z "$ID" ] && CORROTTA=true && MOTIVO="${MOTIVO:+$MOTIVO, }ID mancante"
    [ -z "$NOME" ] && CORROTTA=true && MOTIVO="${MOTIVO:+$MOTIVO, }Nome mancante"
    [ -z "$COGNOME" ] && CORROTTA=true && MOTIVO="${MOTIVO:+$MOTIVO, }Cognome mancante"
    [ -z "$EMAIL" ] && CORROTTA=true && MOTIVO="${MOTIVO:+$MOTIVO, }Email mancante"
    
    RIGA_ORIGINALE="$ID;$NOME;$COGNOME;$DATA;$EMAIL;$SPORT;$ABBONAMENTO;$SCADENZA;$ACCESSO"
    
    if [ "$CORROTTA" = true ]; then
        # Salva la riga corrotta
        echo "$RIGA_ORIGINALE" >> "$OUTPUT_CORROTTE"
        
        echo "  Riga corrotta trovata:"
        echo "   Motivo: $MOTIVO"
        echo "   ID: ${ID:-[VUOTO]} | Nome: ${NOME:-[VUOTO]} ${COGNOME:-[VUOTO]}"
        echo "   Email: ${EMAIL:-[VUOTO]}"
        echo ""
    else
        # Riga valida
        echo "$RIGA_ORIGINALE" >> "$OUTPUT_PULITO"
    fi
done

# Conta le righe finali
NUM_CORROTTE=$(tail -n +2 "$OUTPUT_CORROTTE" 2>/dev/null | wc -l)
NUM_PULITE=$(tail -n +2 "$OUTPUT_PULITO" 2>/dev/null | wc -l)
NUM_TOTALI=$((NUM_CORROTTE + NUM_PULITE))
PERCENTUALE=$(awk "BEGIN {printf \"%.1f\", ($NUM_PULITE * 100) / $NUM_TOTALI}" 2>/dev/null || echo "0.0")

# Mostra i risultati
echo "════════════════════════════════════════"
echo -e "${GREEN}✓ ANALISI COMPLETATA!${NC}"
echo "════════════════════════════════════════"
echo ""
echo " RISULTATI:"
echo "   Totali:    $NUM_TOTALI"
echo "   Valide:    $NUM_PULITE ($PERCENTUALE%)"
echo "   Corrotte:  $NUM_CORROTTE"
echo ""

if [ "$NUM_CORROTTE" -gt 0 ]; then
    echo " File generati:"
    echo "   ✓ $OUTPUT_PULITO   ($NUM_PULITE righe valide)"
    echo "   ✓ $OUTPUT_CORROTTE  ($NUM_CORROTTE righe corrotte)"
    echo ""
    
    # Mostra anteprima delle corrotte
    echo " Anteprima righe corrotte:"
    head -5 "$OUTPUT_CORROTTE" | tail -n +2 | sed 's/^/   /'
else
    rm -f "$OUTPUT_CORROTTE"
    echo -e "${GREEN} Nessun dato corrotto - CSV perfetto!${NC}"
    echo "   ✓ $OUTPUT_PULITO ($NUM_PULITE righe)"
fi

echo ""
echo -e "${GREEN}✓ Script terminato con successo!${NC}"