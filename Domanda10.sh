#!/bin/bash
# Domanda10.sh - Pulizia e recupero dati corrotti
# Alessandro - 2026
#
# Controlla il CSV e trova righe con campi mancanti
# Prova a recuperarle dai backup se esistono
#
# Uso: ./Domanda10.sh

INPUT_CSV="centro_sportivo.csv"
OUTPUT_CORROTTE="righe_corrotte.csv"
OUTPUT_PULITO="centro_sportivo_pulito.csv"
BACKUP_DIR="./backups"

[ ! -f "$INPUT_CSV" ] && echo "Errore: $INPUT_CSV non trovato" && exit 1

echo "Controllo dati corrotti..."
echo ""

# prendo l'header e conto quanti campi deve avere ogni riga
HEADER=$(head -n 1 "$INPUT_CSV")
NUM_CAMPI=$(echo "$HEADER" | awk -F';' '{print NF}')
echo "Il CSV deve avere $NUM_CAMPI campi per riga"
echo ""

echo "$HEADER" > "$OUTPUT_CORROTTE"
echo "$HEADER" > "$OUTPUT_PULITO"

# leggo il CSV riga per riga saltando l'header
tail -n +2 "$INPUT_CSV" | while IFS= read -r line; do

    # estraggo i campi principali per controllarli
    ID=$(echo "$line" | cut -d';' -f1)
    NOME=$(echo "$line" | cut -d';' -f2)
    COGNOME=$(echo "$line" | cut -d';' -f3)
    EMAIL=$(echo "$line" | cut -d';' -f5)
    CAMPI_RIGA=$(echo "$line" | awk -F';' '{print NF}')

    CORROTTA=false
    MOTIVO=""

    # controllo se manca qualcosa
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
        echo "  ID: ${ID:-[VUOTO]} | Nome: ${NOME:-[VUOTO]} ${COGNOME:-[VUOTO]} | Email: ${EMAIL:-[VUOTO]}"

        # provo a recuperarla dai backup se ho almeno nome o cognome
        if ([ -n "$NOME" ] || [ -n "$COGNOME" ]) && [ -d "$BACKUP_DIR" ]; then
            # costruisco il pattern di ricerca con quello che ho
            [ -n "$NOME" ] && [ -n "$COGNOME" ] && PATTERN=";$NOME;$COGNOME;"
            [ -n "$NOME" ] && [ -z "$COGNOME" ] && PATTERN=";$NOME;"
            [ -z "$NOME" ] && [ -n "$COGNOME" ] && PATTERN=";$COGNOME;"

            ULTIMO_BACKUP=$(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null | head -n 1)

            if [ -n "$ULTIMO_BACKUP" ]; then
                # estraggo il backup e cerco la riga usando il pattern
                TROVATO=$(tar -xzf "$ULTIMO_BACKUP" -O 2>/dev/null | grep -F "$PATTERN" | head -n 1)

                if [ -n "$TROVATO" ]; then
                    CAMPI_TROVATA=$(echo "$TROVATO" | awk -F';' '{print NF}')
                    # verifico che la riga trovata sia completa e senza campi vuoti
                    if [ "$CAMPI_TROVATA" -eq "$NUM_CAMPI" ] && ! echo "$TROVATO" | grep -q ';;'; then
                        echo "$TROVATO" >> "$OUTPUT_PULITO"
                        echo "  Recuperata dai backup!"
                    else
                        echo "  Trovata nel backup ma anche lì è corrotta"
                    fi
                else
                    echo "  Non trovata nei backup"
                fi
            else
                echo "  Nessun backup disponibile"
            fi
        else
            echo "  Impossibile cercare (Nome e Cognome entrambi mancanti)"
        fi
        echo ""
    else
        # riga valida, la salvo nel file pulito
        echo "$line" >> "$OUTPUT_PULITO"
    fi
done

# conto le righe nei file generati
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
    echo "  $OUTPUT_PULITO"
    echo "  $OUTPUT_CORROTTE"
else
    rm -f "$OUTPUT_CORROTTE"
    echo ""
    echo "Nessun dato corrotto - CSV perfetto!"
fi
echo ""
