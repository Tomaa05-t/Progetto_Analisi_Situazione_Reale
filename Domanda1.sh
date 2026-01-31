#!/bin/bash

# data di oggi
oggi=$(date +%Y-%m-%d)

# limite certificato medico (certificati scaduti o in scadenza)
limite_certificato=$(date -d "+9 days" +%Y-%m-%d)

# file CSV di input e output
input="centro_sportivo.csv"
output="accessi_negati.csv"

# pulisce il file precedente
> "$output"

awk -F',' -v oggi="$oggi" -v limite="$limite_certificato" '
NR==1 { 
    # intestazione nel file di output
    print "Nome,Cognome,Abbonamento,Scadenza_Certificato,Scadenza_Abbonamento,Motivo" > "'$output'"
    next
}
NR>1 {
    certificato_scaduto = ($8 < limite)
    abbonamento_scaduto = ($10 < oggi)
    
    if (certificato_scaduto || abbonamento_scaduto) {
        motivo=""
        if (certificato_scaduto) motivo="Certificato scaduto"
        if (abbonamento_scaduto) {
            if (motivo != "") motivo=motivo" e "
            motivo=motivo"Abbonamento scaduto"
        }
        print $2","$3","$7","$8","$10","motivo >> "'$output'"
    }
}' "$input"

# mostra riepilogo
echo "Utenti con accesso negato:"
cat "$output"
echo "Totale utenti con accesso negato:"
wc -l < "$output"
