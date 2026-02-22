#!/bin/bash

# Controllo accessi centro sportivo
# Priorità assoluta allo stato di ban
# inserire accesso da tornello


oggi=$(date +%Y-%m-%d)
giorni_preavviso=9
limite_certificato=$(date -d "+$giorni_preavviso days" +%Y-%m-%d)

input="centro_sportivo.csv"
output="accessi_negati/accessi_negati.csv"

echo "Nome,Cognome,Tipo_Abbonamento,Scadenza_Certificato,Scadenza_Abbonamento,Motivo" > "$output"

awk -F';' -v oggi="$oggi" -v limite="$limite_certificato" '
NR > 1 {

    bannato = ($11 == "Sì")
    certificato_non_valido = ($8 <= limite)
    abbonamento_scaduto = ($10 < oggi)

    # PRIORITÀ ASSOLUTA UTENTE BANNATO
    if (bannato) {
        print $2 "," $3 "," $7 "," $8 "," $10 ",Utente bannato"
        next
    }

    
    if (certificato_non_valido || abbonamento_scaduto) {

        motivo=""

        if (certificato_non_valido)
            motivo="Certificato medico scaduto o in scadenza"

        if (abbonamento_scaduto) {
            if (motivo != "") motivo=motivo" e "
            motivo=motivo"Abbonamento scaduto"
        }

        print $2 "," $3 "," $7 "," $8 "," $10 "," motivo
    }
}
' "$input" >> "$output"

totale=$(tail -n +2 "$output" | wc -l)


echo "Controllo accessi completato"
echo "File generato: $output"
echo "Totale utenti con accesso negato: $totale"

