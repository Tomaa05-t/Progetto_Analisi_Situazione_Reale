#!/bin/bash
# Script: Domanda9.sh - Rilevamento Tentativi di Accesso SSH Falliti
# Descrizione: Analizza i file di log del sistema per identificare potenziali
#              attacchi brute-force SSH basati su tentativi di login falliti

# Uso: ./Domanda9.sh [file_log] [soglia_tentativi]


# Esempio: ./Domanda9.sh /var/log/auth.log 5

# CONFIGURAZIONE PARAMETRI

# File di log da analizzare (può essere passato come primo parametro)
LOG_FILE="${1:-./auth.log}"

# Soglia di tentativi falliti per considerare un attacco (default: 5)
SOGLIA_ATTACCO="${2:-5}"

# File di output per salvare gli IP sospetti
OUTPUT_FILE="./salvataggi_ip_sospetti/ip_sospetti_$(date +%Y%m%d_%H%M%S).txt"

# VALIDAZIONE INPUT

# Verifica che il file di log esista
if [ ! -f "$LOG_FILE" ]; then
    echo "ERRORE: Il file di log '$LOG_FILE' non esiste!"
    echo "Uso: $0 [file_log] [soglia_tentativi]"
    echo ""
    echo "Esempio per usare il log di sistema:"
    echo "  sudo $0 /var/log/auth.log 5"
    exit 1
fi

# Verifica che la soglia sia un numero
if ! [[ "$SOGLIA_ATTACCO" =~ ^[0-9]+$ ]]; then
    echo "ERRORE: La soglia deve essere un numero intero!"
    exit 2
fi

# ANALISI LOG SSH

echo "ANALISI TENTATIVI ACCESSO SSH FALLITI"
echo "File log: $LOG_FILE"
echo "Soglia attacco: $SOGLIA_ATTACCO tentativi"
echo "Data analisi: $(date '+%d/%m/%Y %H:%M:%S')"
echo ""

# Filtra le righe con tentativi falliti SSH
# grep cerca le righe con "Failed password"
# awk estrae l'indirizzo IP (campo che viene prima di "port")
# sort ordina gli IP
# uniq -c conta quante volte appare ogni IP
# awk filtra solo gli IP con tentativi >= soglia
echo "Ricerca tentativi falliti..."

grep "Failed password" "$LOG_FILE" | \
    awk '{for(i=1;i<=NF;i++) if($i=="from") print $(i+1)}' | \
    sort | \
    uniq -c | \
    awk -v soglia="$SOGLIA_ATTACCO" '$1 >= soglia {print $1, $2}' > /tmp/ip_analisi.txt

# Verifica se sono stati trovati IP sospetti
if [ ! -s /tmp/ip_analisi.txt ]; then
    echo "Nessun attacco rilevato!"
    echo "  Tutti gli IP hanno meno di $SOGLIA_ATTACCO tentativi falliti."
    echo "========================================" 
    rm -f /tmp/ip_analisi.txt
    exit 0
fi

# REPORT ATTACCHI

echo "ATTACCO IN CORSO - IP SOSPETTI RILEVATI!"
echo ""
echo "IP Address          Tentativi  Status"
echo "----------------------------------------"

# Legge i risultati e li formatta
while read -r count ip; do
    # Determina il livello di minaccia
    if [ "$count" -ge $((SOGLIA_ATTACCO * 3)) ]; then
        STATUS="CRITICO"
    elif [ "$count" -ge $((SOGLIA_ATTACCO * 2)) ]; then
        STATUS="ALTO"
    else
        STATUS="MEDIO"
    fi
    
    printf "%-18s  %-9s  %s\n" "$ip" "$count" "$STATUS"
    
    # Salva nel file di output
    echo "IP: $ip | Tentativi: $count | Livello: $STATUS" >> "$OUTPUT_FILE"
done < /tmp/ip_analisi.txt

echo "----------------------------------------"
echo ""

while read -r count ip; do
    # Stampa solo messaggio breve a schermo
    echo "Analisi IP: $ip..."
    
    # Tutto il resto va solo nel file
    {
        echo ""
        echo "IP: $ip ($count tentativi)"
        echo "Utenti tentati:"
        grep "Failed password" "$LOG_FILE" | \
            grep "from $ip" | \
            awk '{for(i=1;i<=NF;i++) if($i=="for") print $(i+1)}' | \
            sort | uniq -c | sort -rn | head -5
    } >> "$OUTPUT_FILE"
    
done < /tmp/ip_analisi.txt

echo "Report salvato in: $OUTPUT_FILE"

# Pulizia file temporanei
rm -f /tmp/ip_analisi.txt

exit 0