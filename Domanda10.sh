#!/bin/bash
# Domanda10.sh - Pulizia e recupero dati corrotti
# Alessandro - 2026
# Controlla il CSV e trova le righe con campi mancanti
# Per ogni riga corrotta cerca in TUTTI i backup disponibili
# Può cercare con: ID, nome+cognome, nome, cognome, email, o data di nascita
# Uso: ./Domanda10.sh

INPUT_CSV="centro_sportivo.csv"
OUTPUT_CORROTTE="righe_corrotte.csv"
OUTPUT_PULITO="centro_sportivo_pulito.csv"
BACKUP_DIR="./backups"

# controllo che il CSV esista
[ ! -f "$INPUT_CSV" ] && echo "Errore: $INPUT_CSV non trovato" && exit 1

echo "Controllo dati corrotti..."
echo ""

# prendo l'header e conto quanti campi deve avere ogni riga
HEADER=$(head -n 1 "$INPUT_CSV")
NUM_CAMPI=$(echo "$HEADER" | awk -F';' '{print NF}')
echo "Il CSV deve avere $NUM_CAMPI campi per riga"
echo ""

# creo i file di output con l'header
echo "$HEADER" > "$OUTPUT_CORROTTE"
echo "$HEADER" > "$OUTPUT_PULITO"

# leggo il CSV riga per riga saltando l'header
tail -n +2 "$INPUT_CSV" | while IFS= read -r line; do

    # estraggo i campi principali
    ID=$(echo "$line" | cut -d';' -f1)
    NOME=$(echo "$line" | cut -d';' -f2)
    COGNOME=$(echo "$line" | cut -d';' -f3)
    DATA_NASCITA=$(echo "$line" | cut -d';' -f4)
    EMAIL=$(echo "$line" | cut -d';' -f5)
    CAMPI_RIGA=$(echo "$line" | awk -F';' '{print NF}')

    CORROTTA=false
    MOTIVO=""

    # 6 controlli per trovare righe corrotte
    [ "$CAMPI_RIGA" -ne "$NUM_CAMPI" ] && CORROTTA=true && MOTIVO="Campi: $CAMPI_RIGA invece di $NUM_CAMPI"
    [ -z "$ID" ]      && CORROTTA=true && MOTIVO="${MOTIVO:+$MOTIVO, }ID mancante"
    [ -z "$NOME" ]    && CORROTTA=true && MOTIVO="${MOTIVO:+$MOTIVO, }Nome mancante"
    [ -z "$COGNOME" ] && CORROTTA=true && MOTIVO="${MOTIVO:+$MOTIVO, }Cognome mancante"
    [ -z "$EMAIL" ]   && CORROTTA=true && MOTIVO="${MOTIVO:+$MOTIVO, }Email mancante"
    echo "$line" | grep -q ';;' && CORROTTA=true && MOTIVO="${MOTIVO:+$MOTIVO, }Campo vuoto"

    if [ "$CORROTTA" = true ]; then
        echo "$line" >> "$OUTPUT_CORROTTE"
        echo "Riga corrotta:"
        echo "  Motivo: $MOTIVO"
        echo "  ID: ${ID:-[VUOTO]} | Nome: ${NOME:-[VUOTO]} ${COGNOME:-[VUOTO]}"
        echo "  Data: ${DATA_NASCITA:-[VUOTO]} | Email: ${EMAIL:-[VUOTO]}"

        # costruisco il pattern di ricerca in base a cosa ho disponibile
        # provo in ordine: ID, nome+cognome, solo nome, solo cognome, email, data nascita
        PATTERN=""
        TIPO_RICERCA=""
        
        if [ -n "$ID" ]; then
            PATTERN=";$ID;"
            TIPO_RICERCA="ID"
        elif [ -n "$NOME" ] && [ -n "$COGNOME" ]; then
            PATTERN=";$NOME;$COGNOME;"
            TIPO_RICERCA="nome e cognome"
        elif [ -n "$NOME" ]; then
            PATTERN=";$NOME;"
            TIPO_RICERCA="nome"
        elif [ -n "$COGNOME" ]; then
            PATTERN=";$COGNOME;"
            TIPO_RICERCA="cognome"
        elif [ -n "$EMAIL" ]; then
            PATTERN=";$EMAIL;"
            TIPO_RICERCA="email"
        elif [ -n "$DATA_NASCITA" ]; then
            PATTERN=";$DATA_NASCITA;"
            TIPO_RICERCA="data di nascita"
        fi

        # se ho un pattern valido, cerco in TUTTI i backup
        if [ -n "$PATTERN" ] && [ -d "$BACKUP_DIR" ]; then
            echo "  Cerco con $TIPO_RICERCA in tutti i backup..."
            
            # prendo TUTTI i backup ordinati dal più recente
            BACKUPS=($(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null))
            
            if [ ${#BACKUPS[@]} -eq 0 ]; then
                echo "  Nessun backup disponibile"
            else
                TROVATO=""
                BACKUP_TROVATO=""
                
                # cerco in ogni backup finché non trovo una riga valida
                for BACKUP in "${BACKUPS[@]}"; do
                    # estraggo il backup e cerco il pattern
                    RIGA=$(tar -xzf "$BACKUP" -O 2>/dev/null | grep -F "$PATTERN" | head -n 1)
                    
                    if [ -n "$RIGA" ]; then
                        # verifico che la riga sia completa e valida
                        CAMPI_TROVATA=$(echo "$RIGA" | awk -F';' '{print NF}')
                        
                        if [ "$CAMPI_TROVATA" -eq "$NUM_CAMPI" ] && ! echo "$RIGA" | grep -q ';;'; then
                            # trovata una riga valida!
                            TROVATO="$RIGA"
                            BACKUP_TROVATO=$(basename "$BACKUP")
                            break
                        fi
                    fi
                done
                
                # mostro il risultato
                if [ -n "$TROVATO" ]; then
                    echo "$TROVATO" >> "$OUTPUT_PULITO"
                    echo "  ✓ Recuperata da: $BACKUP_TROVATO"
                else
                    echo "  ✗ Non trovata in nessun backup"
                fi
            fi
        else
            echo "  ✗ Impossibile cercare (tutti i campi chiave mancanti)"
        fi
        echo ""
    else
        # riga valida, la salvo nel file pulito
        echo "$line" >> "$OUTPUT_PULITO"
    fi
done

# statistiche finali
NUM_CORROTTE=$(tail -n +2 "$OUTPUT_CORROTTE" 2>/dev/null | wc -l)
NUM_PULITE=$(tail -n +2 "$OUTPUT_PULITO" 2>/dev/null | wc -l)
NUM_TOTALI=$(tail -n +2 "$INPUT_CSV" | wc -l)
PERCENTUALE=$(awk "BEGIN {printf \"%.1f\", ($NUM_PULITE * 100) / $NUM_TOTALI}")

echo "Analisi completata!"
echo ""
echo "RISULTATI:"
echo "  Totali:    $NUM_TOTALI"
echo "  Valide:    $NUM_PULITE ($PERCENTUALE%)"
echo "  Corrotte:  $NUM_CORROTTE"

if [ "$NUM_CORROTTE" -gt 0 ]; then
    echo ""
    echo "File generati:"
    echo "  $OUTPUT_PULITO       (righe valide + recuperate)"
    echo "  $OUTPUT_CORROTTE     (righe originali corrotte)"
else
    rm -f "$OUTPUT_CORROTTE"
    echo ""
    echo "✓ Nessun dato corrotto - CSV perfetto!"
fi
echo ""