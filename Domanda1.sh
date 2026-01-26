#!/bin/bash
#chi può entrare
oggi=$(date +%F)
nuovo_limite_cerificato=$(date "9 days" +%F)

awk -F, 'NR>1 {if ($8 >= "'"$nuovo_limite_cerificato"'") print ($2, $3 "non può accedere al centro sportivo )

if $7 == "Mensile":
            scadenza_abbonamento = (oggi + timedelta(days=30)).strftime("%Y-%m-%d")
        elif $7 == "Trimestrale":
            scadenza_abbonamento = (oggi + timedelta(days=90)).strftime("%Y-%m-%d")
        elif $7 == "Semestrale":
            scadenza_abbonamento = (oggi + timedelta(days=180)).strftime("%Y-%m-%d")
        else:  # Annuale
            scadenza_abbonamento = (oggi + timedelta(days=365)).strftime("%Y-%m-%d") }' centro_sportivo.csv > accessi_negati_certificato_scaduto.csv

