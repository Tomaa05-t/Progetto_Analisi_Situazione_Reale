#!/bin/bash

# Rilevamento accessi nel range di date scelto
input="centro_sportivo.csv"
input2="accessi_orario.csv"
output1="accessi_ultimi.csv"
output2="accessi_dettagliati.csv"

# Controlla se ci sono argomenti passati (da Streamlit o script)
if [[ $# -eq 3 ]]; then
    # Modo non-interattivo: argomenti passati come parametri
    data_inizio=$1
    data_fine=$2
    opzione=$3
else
    # Modo interattivo
    echo "=== RICERCA ACCESSI CENTRO SPORTIVO ==="
    echo ""
    
    # Richiesta data inizio
    read -p "Inserisci la data di inizio (YYYY-MM-DD): " data_inizio < /dev/tty
    
    if ! date -d "$data_inizio" >/dev/null 2>&1; then
        echo "Data di inizio NON valida"
        exit 1
    fi
    
    # Richiesta data fine
    read -p "Inserisci la data di fine (YYYY-MM-DD): " data_fine < /dev/tty
    
    if ! date -d "$data_fine" >/dev/null 2>&1; then
        echo "Data di fine NON valida"
        exit 1
    fi
    
    # Validazione: data_fine >= data_inizio
    if [[ "$data_fine" < "$data_inizio" ]]; then
        echo "La data di fine deve essere successiva o uguale alla data di inizio"
        exit 1
    fi
    
    echo ""
    echo "Scegli cosa visualizzare:"
    echo "1) Ultimi accessi registrati nel centro sportivo"
    echo "2) Accessi dettagliati ora per ora nel lasso di giorni scelto"
    echo ""
    read -p "Inserisci il numero dell'opzione (1 o 2): " opzione < /dev/tty
fi

# Normalizza le date
data_inizio=$(date -d "$data_inizio" +%Y-%m-%d)
data_fine=$(date -d "$data_fine" +%Y-%m-%d)

case $opzione in
    1)
        echo ""
        echo "Ricerca in corso..."
        
        awk -F';' -v inizio="$data_inizio" -v fine="$data_fine" 'NR==1 {print "Nome;Cognome;Ultimo_Accesso;Sport;Abbonamento"} NR>1 {if ($9 >= inizio && $9 <= fine) print $2 ";" $3 ";" $9 ";" $6 ";" $7}' "$input" > "$output1"
        
        conta=$(tail -n +2 "$output1" | wc -l)
        
        echo ""
        echo "✓ Ricerca completata!"
        echo "Utenti con ultimi accessi dal $data_inizio al $data_fine: $conta"
        echo "Risultati salvati in: $output1"
        echo ""
        echo "=== ANTEPRIMA ===" 
        head -10 "$output1"
        ;;
        
    2)
        echo ""
        echo "⏳ Generazione accessi dettagliati in corso..."
        
        # Calcola il numero di giorni nel range
        data_inizio_sec=$(date -d "$data_inizio" +%s)
        data_fine_sec=$(date -d "$data_fine" +%s)
        giorni=$(( (data_fine_sec - data_inizio_sec) / 86400 + 1 ))
        
        # Crea il file di output con header
        echo "ID;Nome;Cognome;Data_Accesso;Orario_Entrata;Orario_Uscita" > "$output2"
        
        # Leggi file senza usare pipe (evita hang di stdin)
        {
            read -r header  # skip header
            while IFS=';' read -r id nome cognome orario_entrata orario_uscita; do
                # Genera una data casuale nel range
                giorni_random=$((RANDOM % giorni))
                data_casuale=$(date -d "$data_inizio + $giorni_random days" +%Y-%m-%d)
                
                # Scrivi i dati
                echo "$id;$nome;$cognome;$data_casuale;$orario_entrata;$orario_uscita" >> "$output2"
            done
        } < "$input2"
        
        conta=$(tail -n +2 "$output2" | wc -l)
        
        echo ""
        echo "✓ Generazione completata!"
        echo "Accessi dettagliati generati dal $data_inizio al $data_fine: $conta"
        echo "Risultati salvati in: $output2"
        echo ""
        echo "=== ANTEPRIMA ===" 
        head -10 "$output2"
        ;;
        
    *)
        echo "Opzione non valida. Inserisci 1 o 2"
        exit 1
        ;;
esac

echo ""
echo "✓ Script terminato con successo!"