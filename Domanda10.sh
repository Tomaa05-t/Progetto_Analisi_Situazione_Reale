#!/bin/bash
# Domanda10.sh - Pulizia e recupero dati corrotti

#
# Controlla il CSV del centro sportivo e trova le righe con campi mancanti
# Per ogni riga corrotta prova a recuperare i dati dal backup più recente
#
# Uso: ./Domanda10.sh

INPUT_CSV="centro_sportivo.csv"
OUTPUT_CORROTTE="righe_corrotte.csv"
OUTPUT_PULITO="centro_sportivo_pulito.csv"
BACKUP_DIR="./backups"

# controllo che il CSV esista
[ ! -f "$INPUT_CSV" ] && echo "Errore: $INPUT_CSV non trovato" && exit 1

echo "Controllo dati corrotti..."
echo ""

# prendo la prima riga (header) per sapere quanti campi deve avere ogni riga
# esempio di header: ID;Nome;Cognome;Data_Nascita;Email;Sport;...
HEADER=$(head -n 1 "$INPUT_CSV")

# conto quanti campi ci sono nell'header usando ; come separatore
# awk -F';' usa il punto e virgola come delimitatore
# {print NF} stampa il Number of Fields (numero di campi)
NUM_CAMPI=$(echo "$HEADER" | awk -F';' '{print NF}')
echo "Il CSV deve avere $NUM_CAMPI campi per riga"
echo ""

# creo i due file di output con l'header dentro
echo "$HEADER" > "$OUTPUT_CORROTTE"
echo "$HEADER" > "$OUTPUT_PULITO"

# leggo il CSV riga per riga saltando l'header
# tail -n +2 prende tutto dalla riga 2 in poi (salta la prima)
# IFS= read -r line legge la riga completa senza dividere i campi
tail -n +2 "$INPUT_CSV" | while IFS= read -r line; do

    # estraggo i campi principali da controllare
    # cut -d';' usa ; come delimitatore, -f1 prende il campo 1, -f2 il campo 2, ecc.
    ID=$(echo "$line" | cut -d';' -f1)
    NOME=$(echo "$line" | cut -d';' -f2)
    COGNOME=$(echo "$line" | cut -d';' -f3)
    EMAIL=$(echo "$line" | cut -d';' -f5)
    
    # conto quanti campi ha questa riga specifica
    CAMPI_RIGA=$(echo "$line" | awk -F';' '{print NF}')

    CORROTTA=false
    MOTIVO=""

    # faccio 6 controlli diversi per vedere se la riga è corrotta
    
    # controllo 1: numero di campi sbagliato
    [ "$CAMPI_RIGA" -ne "$NUM_CAMPI" ] && CORROTTA=true && MOTIVO="Campi: $CAMPI_RIGA invece di $NUM_CAMPI"
    
    # controllo 2, 3, 4, 5: campi vuoti
    # [ -z "$VAR" ] è vero se la variabile è vuota
    [ -z "$ID" ]      && CORROTTA=true && MOTIVO="${MOTIVO:+$MOTIVO, }ID mancante"
    [ -z "$NOME" ]    && CORROTTA=true && MOTIVO="${MOTIVO:+$MOTIVO, }Nome mancante"
    [ -z "$COGNOME" ] && CORROTTA=true && MOTIVO="${MOTIVO:+$MOTIVO, }Cognome mancante"
    [ -z "$EMAIL" ]   && CORROTTA=true && MOTIVO="${MOTIVO:+$MOTIVO, }Email mancante"
    
    # controllo 6: campi vuoti in mezzo (tipo 1;Mario;;...)
    # grep -q ';;' cerca due ; consecutivi = campo vuoto nel mezzo
    echo "$line" | grep -q ';;' && CORROTTA=true && MOTIVO="${MOTIVO:+$MOTIVO, }Campo vuoto"

    if [ "$CORROTTA" = true ]; then
        # ho trovato una riga corrotta, la salvo nel file delle corrotte
        echo "$line" >> "$OUTPUT_CORROTTE"
        
        # mostro a schermo cosa ho trovato
        echo "Riga corrotta:"
        echo "  Motivo: $MOTIVO"
        # ${VAR:-[VUOTO]} stampa [VUOTO] se la variabile è vuota
        echo "  ID: ${ID:-[VUOTO]} | Nome: ${NOME:-[VUOTO]} ${COGNOME:-[VUOTO]} | Email: ${EMAIL:-[VUOTO]}"

        # provo a recuperare la riga dai backup
        # posso cercare solo se ho almeno il nome O il cognome
        # se mancano entrambi non so cosa cercare
        if ([ -n "$NOME" ] || [ -n "$COGNOME" ]) && [ -d "$BACKUP_DIR" ]; then
            
            # costruisco il pattern di ricerca in base a cosa ho
            # se ho entrambi cerco ";Nome;Cognome;"
            # se ho solo uno dei due cerco ";Nome;" o ";Cognome;"
            if [ -n "$NOME" ] && [ -n "$COGNOME" ]; then
                PATTERN=";$NOME;$COGNOME;"
            elif [ -n "$NOME" ]; then
                PATTERN=";$NOME;"
            else
                PATTERN=";$COGNOME;"
            fi

            # prendo il backup più recente
            # ls -t ordina per data (più recenti prima)
            # head -n 1 prende solo il primo
            ULTIMO_BACKUP=$(ls -t "$BACKUP_DIR"/centro_sportivo_backup_*.tar.gz 2>/dev/null | head -n 1)

            if [ -n "$ULTIMO_BACKUP" ]; then
                # estraggo il backup in memoria e cerco la riga
                # tar -xzf estrae, -O manda su stdout invece che su disco
                # grep -F cerca il pattern esatto (non regex)
                # head -n 1 prende solo la prima riga trovata
                TROVATO=$(tar -xzf "$ULTIMO_BACKUP" -O 2>/dev/null | grep -F "$PATTERN" | head -n 1)

                if [ -n "$TROVATO" ]; then
                    # ho trovato qualcosa, verifico che sia completa
                    CAMPI_TROVATA=$(echo "$TROVATO" | awk -F';' '{print NF}')
                    
                    # la riga deve avere il numero giusto di campi E non deve avere ;;
                    if [ "$CAMPI_TROVATA" -eq "$NUM_CAMPI" ] && ! echo "$TROVATO" | grep -q ';;'; then
                        # perfetto! la riga è completa e valida
                        echo "$TROVATO" >> "$OUTPUT_PULITO"
                        echo "  ✓ Recuperata dai backup!"
                    else
                        echo "  ✗ Trovata nel backup ma anche lì è corrotta"
                    fi
                else
                    echo "  ✗ Non trovata nei backup"
                fi
            else
                echo "  Nessun backup disponibile"
            fi
        else
            # non ho né nome né cognome, impossibile cercare
            echo "  ✗ Impossibile cercare (Nome e Cognome entrambi mancanti)"
        fi
        echo ""
    else
        # la riga è valida, la salvo direttamente nel file pulito
        echo "$line" >> "$OUTPUT_PULITO"
    fi
done

# conto le righe nei file generati (escluso l'header)
# tail -n +2 salta la prima riga (l'header)
# wc -l conta le righe
NUM_CORROTTE=$(tail -n +2 "$OUTPUT_CORROTTE" 2>/dev/null | wc -l)
NUM_PULITE=$(tail -n +2 "$OUTPUT_PULITO" 2>/dev/null | wc -l)
NUM_TOTALI=$(tail -n +2 "$INPUT_CSV" | wc -l)

# calcolo la percentuale di righe valide
# awk fa i calcoli con i decimali, printf formatta con 1 decimale
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
    # se non ci sono righe corrotte cancello il file vuoto
    rm -f "$OUTPUT_CORROTTE"
    echo ""
    echo "✓ Nessun dato corrotto - CSV perfetto!"
fi
echo ""