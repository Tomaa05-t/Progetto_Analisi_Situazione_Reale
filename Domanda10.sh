#!/bin/bash
#
# Script: Domanda10.sh - Pulizia Dati Corrotti Centro Sportivo
# Autore: Alessandro
# Descrizione: Identifica e rimuove le righe corrotte dal database CSV
#              (righe senza ID o senza email)
#
# Uso: ./Domanda10.sh [file_csv_input] [file_csv_output]
#      Se non specificati, usa i valori predefiniti
#
# Esempio: ./Domanda10.sh centro_sportivo.csv centro_sportivo_pulito.csv
#

# ============================================================================
# CONFIGURAZIONE PARAMETRI
# ============================================================================

# File CSV da pulire (può essere passato come primo parametro)
INPUT_FILE="${1:-centro_sportivo.csv}"

# File CSV pulito di output (può essere passato come secondo parametro)
OUTPUT_FILE="${2:-centro_sportivo_pulito.csv}"

# File di log con le righe scartate
REJECTED_FILE="righe_corrotte_$(date +%Y%m%d_%H%M%S).csv"

# ============================================================================
# VALIDAZIONE INPUT
# ============================================================================

# Verifica che il file di input esista
if [ ! -f "$INPUT_FILE" ]; then
    echo "ERRORE: Il file '$INPUT_FILE' non esiste!"
    echo "Uso: $0 [file_csv_input] [file_csv_output]"
    exit 1
fi

# Verifica che il file di output non sia uguale all'input
if [ "$INPUT_FILE" == "$OUTPUT_FILE" ]; then
    echo "ATTENZIONE: Il file di output è uguale all'input!"
    echo "I dati originali verranno sovrascritti."
    read -p "Continuare? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "Operazione annullata."
        exit 0
    fi
fi

# ============================================================================
# ANALISI E PULIZIA DATI
# ============================================================================

echo "========================================" 
echo "PULIZIA DATI CORROTTI"
echo "========================================"
echo "File input: $INPUT_FILE"
echo "File output: $OUTPUT_FILE"
echo "Data: $(date '+%d/%m/%Y %H:%M:%S')"
echo ""

# Conta le righe totali (escluso header)
# tail -n +2 salta la prima riga (header)
# wc -l conta le righe
TOTAL_LINES=$(tail -n +2 "$INPUT_FILE" | wc -l)

echo "Righe totali da analizzare: $TOTAL_LINES"
echo ""

# Copia l'header nel file di output e nel file rejected
# head -n 1 prende solo la prima riga
head -n 1 "$INPUT_FILE" > "$OUTPUT_FILE"
head -n 1 "$INPUT_FILE" > "$REJECTED_FILE"

echo "Analisi in corso..."

# ============================================================================
# PROCESSO DI VALIDAZIONE
# ============================================================================

# Legge il file CSV riga per riga (saltando l'header)
# La variabile IFS= mantiene gli spazi
tail -n +2 "$INPUT_FILE" | while IFS= read -r line; do
    # Estrae il primo campo (ID) usando cut
    # -d',' specifica il delimitatore (virgola)
    # -f1 seleziona il primo campo
    ID=$(echo "$line" | cut -d',' -f1)
    
    # Estrae il quinto campo (Email)
    # Nel CSV: ID,Nome,Cognome,Data_Nascita,Email,...
    EMAIL=$(echo "$line" | cut -d',' -f5)
    
    # Determina se la riga è valida
    VALID=true
    REASON=""
    
    # Controlla se ENTRAMBI i campi sono vuoti
    # [ -z "$VAR" ] controlla se la variabile è vuota
    if [ -z "$ID" ] && [ -z "$EMAIL" ]; then
        VALID=false
        REASON="ID e Email mancanti"
        echo "$line,SCARTATA: $REASON" >> "$REJECTED_FILE"
        
    # Controlla se solo l'ID è vuoto
    elif [ -z "$ID" ]; then
        VALID=false
        REASON="ID mancante"
        echo "$line,SCARTATA: $REASON" >> "$REJECTED_FILE"
        
    # Controlla se solo l'Email è vuota
    elif [ -z "$EMAIL" ]; then
        VALID=false
        REASON="Email mancante"
        echo "$line,SCARTATA: $REASON" >> "$REJECTED_FILE"
        
    # La riga è valida, salvala nel file pulito
    else
        echo "$line" >> "$OUTPUT_FILE"
    fi
done

# ============================================================================
# CALCOLO STATISTICHE
# ============================================================================

# Conta le righe valide (escluso header)
VALID_COUNT=$(tail -n +2 "$OUTPUT_FILE" | wc -l)

# Conta le righe scartate (escluso header)
REJECTED_COUNT=$(tail -n +2 "$REJECTED_FILE" | wc -l)

# ============================================================================
# REPORT FINALE
# ============================================================================

echo ""
echo "========================================" 
echo "REPORT PULIZIA COMPLETATO"
echo "========================================"
echo ""
echo "Statistiche:"
echo "----------------------------------------"
echo "Righe analizzate:        $TOTAL_LINES"
echo "Righe valide:            $VALID_COUNT"
echo "Righe corrotte:          $REJECTED_COUNT"
echo ""
echo "File generati:"
echo "----------------------------------------"
echo "✓ Database pulito:       $OUTPUT_FILE"

# Se ci sono righe scartate, mostra il file e un'anteprima
if [ "$REJECTED_COUNT" -gt 0 ]; then
    echo "⚠ Righe scartate:        $REJECTED_FILE"
    echo ""
    echo "Anteprima righe scartate (prime 5):"
    echo "----------------------------------------"
    # head -n 6 prende le prime 6 righe (header + 5 dati)
    # tail -n 5 prende le ultime 5 (esclude l'header)
    head -n 6 "$REJECTED_FILE" | tail -n 5
else
    # Se non ci sono righe scartate, elimina il file rejected
    rm -f "$REJECTED_FILE"
    echo "✓ Nessuna riga scartata - database già pulito!"
fi

echo ""
echo "========================================" 

# Calcola la percentuale di dati validi
if [ "$TOTAL_LINES" -gt 0 ]; then
    # awk viene usato per fare calcoli in virgola mobile
    CLEAN_PERCENTAGE=$(awk "BEGIN {printf \"%.1f\", ($VALID_COUNT * 100) / $TOTAL_LINES}")
    echo "Qualità dati: ${CLEAN_PERCENTAGE}% validi"
fi

echo "========================================" 

# Codice di uscita 0 = successo
exit 0