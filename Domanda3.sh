#!/bin/bash
# Avviso di scadenza certificato medico via email

CSV_FILE="centro_sportivo.csv"
DELIMITER=";"

COL_NOME=2
COL_COGNOME=3
COL_EMAIL=5
COL_SCADENZA=8

GIORNI_PREAVVISO=30
GIORNI_TOLLERANZA=9

OGGI=$(date +%Y-%m-%d)
LIMITE=$(date -d "+$GIORNI_PREAVVISO days" +%Y-%m-%d)


command -v sendmail >/dev/null || {
  echo "sendmail non installato"
  sudo apt update && sudo apt install -y sendmail
  exit 1
}
conteggio=0


awk -F"$DELIMITER" -v oggi="$OGGI" -v limite="$LIMITE" \
    -v tol="$GIORNI_TOLLERANZA" \
    -v n="$COL_NOME" -v c="$COL_COGNOME" \
    -v e="$COL_EMAIL" -v s="$COL_SCADENZA" '
NR>1 && $s >= oggi && $s <= limite {
    cmd = "date -d \"" $s " +" tol " days\" +%Y-%m-%d"
    cmd | getline nuova_scadenza
    close(cmd)

    print $e "|" $n "|" $c "|" $s "|" nuova_scadenza
}' "$CSV_FILE" | while IFS="|" read email nome cognome scadenza nuova_scadenza
do
sendmail -t <<EOF
To: $email
Subject: Avviso di scadenza certificato medico

Caro/a $nome $cognome,

il tuo certificato medico è scaduto il $scadenza.
Hai tempo fino al $nuova_scadenza per rinnovarlo prima di perdere
l'accesso ai servizi del centro sportivo.

Grazie per la collaborazione.
EOF
((conteggio++))
done
echo "Totale e-mail inviate: $conteggio"