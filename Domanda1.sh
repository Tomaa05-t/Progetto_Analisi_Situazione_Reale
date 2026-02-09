#!/bin/bash
# =======================0==================================
# Programma: controllo_accessi.sh
# Descrizione:
#   Il programma verifica la validità del certificato medico,
#   dell’abbonamento e l’eventuale stato di ban degli utenti.
#   Gli utenti non idonei all’accesso vengono salvati nel file
#   accessi_negati.csv con il relativo motivo.
# ==========================================================


oggi=$(date +%Y-%m-%d)
giorni_preavviso=9
limite_certificato=$(date -d "+$giorni_preavviso days" +%Y-%m-%d)


input="centro_sportivo.csv"
output="accessi_negati.csv"


echo "Nome,Cognome,Tipo_Abbonamento,Scadenza_Certificato,Scadenza_Abbonamento,Motivo" > "$output"


awk -F',' -v oggi="$oggi" -v limite="$limite_certificato" '
NR > 1 {

    # Controlli
    certificato_non_valido = ($8 <= limite)
    abbonamento_scaduto   = ($10 < oggi)
    bannato               = ($11 == "Sì")

    # Se almeno una condizione è vera → accesso negato
    if (certificato_non_valido || abbonamento_scaduto || bannato) {

        motivo = ""

        if (certificato_non_valido)
            motivo = "Certificato medico scaduto o in scadenza"

        if (abbonamento_scaduto) {
            if (motivo != "") motivo = motivo " e "
            motivo = motivo "Abbonamento scaduto"
        }

        if (bannato) { "
            motivo = "Utente bannato"
        }

        print $2 "," $3 "," $7 "," $8 "," $10 "," motivo
    }
}
' "$input" >> "$output"


totale=$(tail -n +2 "$output" | wc -l)


echo "------------------------------------------"
echo "Controllo accessi completato con successo."
echo "File generato: $output"
echo "Totale utenti con accesso negato: $totale"
echo "------------------------------------------"
