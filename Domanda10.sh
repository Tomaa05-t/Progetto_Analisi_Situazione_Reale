#!/bin/bash
# Domanda10.sh - Pulizia e recupero dati corrotti
# Alessandro - 2026
#
# Controlla il CSV e trova righe corrotte (qualsiasi campo mancante)
# Prova a recuperarle dai backup se esistono
#
# Uso: ./Domanda10.sh

# File da controllare
INPUT_CSV="centro_sportivo.csv"
OUTPUT_CORROTTE="righe_corrotte.csv"
OUTPUT_PULITO="centro_sportivo_pulito.csv"
BACKUP_DIR="./backups"

# Controllo che il CSV esista
if [ ! -f "$INPUT_CSV" ]; then
    echo "Errore: File $INPUT_CSV non trovato"
    exit 1
fi

echo "Controllo dati corrotti nel CSV..."
echo ""

# Prendo l'header (prima riga) per sapere quanti campi ci devono essere
HEADER=$(head -n 1 "$INPUT_CSV")

# Conto quanti campi ci sono nell'header
NUM_CAMPI=$(echo "$HEADER" | awk -F';' '{print NF}')

echo "Il CSV deve avere $NUM_CAMPI campi per riga"
echo ""

# Creo i file di output con l'header
echo "$HEADER" > "$OUTPUT_CORROTTE"
echo "$HEADER" > "$OUTPUT_PULITO"

# Contatori
TOTALI=0
CORROTTE=0
RECUPERATE=0

# Leggo il CSV riga per riga (salto l'header)
tail -n +2 "$INPUT_CSV" | while IFS= read -r line; do
    TOTALI=$((TOTALI + 1))
    
    # Conto quanti campi ha questa riga
    CAMPI_RIGA=$(echo "$line" | awk -F';' '{print NF}')
    
    # Estraggo i primi campi per vedere cosa manca
    ID=$(echo "$line" | cut -d';' -f1)
    NOME=$(echo "$line" | cut -d';' -f2)
    COGNOME=$(echo "$line" | cut -d';' -f3)
    EMAIL=$(echo "$line" | cut -d';' -f5)
    
    # Variabile per tracciare se la riga è corrotta
    CORROTTA=false
    MOTIVO=""
    
    # Controllo 1: Numero di campi sbagliato
    if [ "$CAMPI_RIGA" -ne "$NUM_CAMPI" ]; then
        CORROTTA=true
        MOTIVO="Campi: $CAMPI_RIGA invece di $NUM_CAMPI"
    fi
    
    # Controllo 2: ID vuoto
    if [ -z "$ID" ]; then
        CORROTTA=true
        MOTIVO="${MOTIVO:+$MOTIVO, }ID mancante"
    fi
    
    # Controllo 3: Nome vuoto
    if [ -z "$NOME" ]; then
        CORROTTA=true
        MOTIVO="${MOTIVO:+$MOTIVO, }Nome mancante"
    fi
    
    # Controllo 4: Cognome vuoto
    if [ -z "$COGNOME" ]; then
        CORROTTA=true
        MOTIVO="${MOTIVO:+$MOTIVO, }Cognome mancante"
    fi
    
    # Controllo 5: Email vuota
    if [ -z "$EMAIL" ]; then
        CORROTTA=true
        MOTIVO="${MOTIVO:+$MOTIVO, }Email mancante"
    fi
    
    # Controllo 6: Campi vuoti in mezzo (es: ;;)
    if echo "$line" | grep -q ';;'; then
        CORROTTA=true
        MOTIVO="${MOTIVO:+$MOTIVO, }Campo vuoto rilevato"
    fi
    
    # Se la riga è corrotta
    if [ "$CORROTTA" = true ]; then
        # La salvo nel file corrotte
        echo "$line" >> "$OUTPUT_CORROTTE"
        CORROTTE=$((CORROTTE + 1))
        
        echo "Riga corrotta #$TOTALI:"
        echo "  Motivo: $MOTIVO"
        echo "  ID: ${ID:-[VUOTO]}"
        echo "  Nome: ${NOME:-[VUOTO]} ${COGNOME:-[VUOTO]}"
        echo "  Email: ${EMAIL:-[VUOTO]}"
        
        # Provo a recuperare dai backup
        # Basta avere ALMENO Nome O Cognome (o entrambi) per cercare
        if ([ -n "$NOME" ] || [ -n "$COGNOME" ]) && [ -d "$BACKUP_DIR" ]; then
            # Costruisco il pattern di ricerca in base a cosa ho
            if [ -n "$NOME" ] && [ -n "$COGNOME" ]; then
                PATTERN=";$NOME;$COGNOME;"
                echo "  Cerco nei backup usando: $NOME $COGNOME"
            elif [ -n "$NOME" ]; then
                PATTERN=";$NOME;"
                echo "  Cerco nei backup usando solo: $NOME"
            else
                PATTERN=";$COGNOME;"
                echo "  Cerco nei backup usando solo: $COGNOME"
            fi
            
            # Prendo il backup più recente
            ULTIMO_BACKUP=$(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null | head -n 1)
            
            if [ -n "$ULTIMO_BACKUP" ]; then
                # Estraggo il CSV dal backup e cerco la riga
                TROVATO=$(tar -xzf "$ULTIMO_BACKUP" -O 2>/dev/null | \
                    grep -F "$PATTERN" | head -n 1)
                
                if [ -n "$TROVATO" ]; then
                    # Verifico che la riga trovata sia completa
                    CAMPI_TROVATA=$(echo "$TROVATO" | awk -F';' '{print NF}')
                    
                    if [ "$CAMPI_TROVATA" -eq "$NUM_CAMPI" ]; then
                        # Verifico che non abbia campi vuoti
                        if ! echo "$TROVATO" | grep -q ';;'; then
                            # Ho trovato una riga completa e valida!
                            echo "$TROVATO" >> "$OUTPUT_PULITO"
                            echo "  ✓ Recuperata dai backup (completa e valida)!"
                            RECUPERATE=$((RECUPERATE + 1))
                        else
                            echo "  ✗ Trovata nei backup ma ha campi vuoti"
                        fi
                    else
                        echo "  ✗ Trovata nei backup ma anche lì è corrotta"
                    fi
                else
                    echo "  ✗ Non trovata nei backup"
                fi
            else
                echo "  Nessun backup disponibile"
            fi
        else
            echo "  ✗ Impossibile cercare (Nome E Cognome entrambi mancanti)"
        fi
        echo ""
    else
        # Riga valida, la salvo nel file pulito
        echo "$line" >> "$OUTPUT_PULITO"
    fi
done

# Conto le righe nei file generati (escluso header)
NUM_CORROTTE=$(tail -n +2 "$OUTPUT_CORROTTE" 2>/dev/null | wc -l)
NUM_PULITE=$(tail -n +2 "$OUTPUT_PULITO" 2>/dev/null | wc -l)
NUM_TOTALI=$(tail -n +2 "$INPUT_CSV" | wc -l)

# Calcolo percentuale dati validi
if [ "$NUM_TOTALI" -gt 0 ]; then
    PERCENTUALE=$(awk "BEGIN {printf \"%.1f\", ($NUM_PULITE * 100) / $NUM_TOTALI}")
fi

# Mostro i risultati
echo "Analisi completata!"
echo ""
echo "RISULTATI:"
echo "  Righe totali:         $NUM_TOTALI"
echo "  Righe valide:         $NUM_PULITE ($PERCENTUALE%)"
echo "  Righe corrotte:       $NUM_CORROTTE"

if [ "$NUM_CORROTTE" -gt 0 ]; then
    echo "  Righe recuperate:     $RECUPERATE"
    echo ""
    echo "File generati:"
    echo "  Dati puliti:          $OUTPUT_PULITO"
    echo "  Dati corrotti:        $OUTPUT_CORROTTE"
    
    # Se ho recuperato qualcosa dai backup
    if [ "$RECUPERATE" -gt 0 ]; then
        echo ""
        echo "✓ Ho recuperato $RECUPERATE righe dai backup!"
        echo "  Sono state aggiunte al file pulito"
    fi
    
    echo ""
    echo "Prime 5 righe corrotte:"
    head -n 6 "$OUTPUT_CORROTTE" | tail -n 5
else
    # Nessuna riga corrotta, elimino il file vuoto
    rm -f "$OUTPUT_CORROTTE"
    echo ""
    echo "✓ Nessun dato corrotto - CSV perfetto!"
fi

echo ""
