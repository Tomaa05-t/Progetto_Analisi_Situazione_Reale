#!/bin/bash

oggi=$(date +%Y-%m-%d)

# limite certificato medico (certificati scaduti o in scadenza da 9 gior)
limite_certificato=$(date -d "+9 days" +%Y-%m-%d)


input="centro_sportivo.csv"
output="accessi_negati.csv"

> "$output"

awk -F',' -v oggi="$oggi" -v limite="$limite_certificato" '
NR==1 { 
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

echo "Elenco degli utenti con accesso negato salvato in $output"
echo "Totale utenti con accesso negato:"
wc -l < "$output"
