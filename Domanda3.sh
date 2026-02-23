#!/bin/bash
# Avviso di scadenza certificato medico via email - VERSIONE CORRETTA

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

# Verifica file CSV
if [[ ! -f "$CSV_FILE" ]]; then
    echo "Errore: file $CSV_FILE non trovato"
    exit 1
fi

# Installa mail se necessario
if ! command -v mail &> /dev/null; then
    echo "Installazione di mailutils..."
    sudo apt update && sudo apt install -y mailutils || exit 1
fi

conteggio_elaborate=0
conteggio_inviate=0
conteggio_errori=0

awk -F"$DELIMITER" -v oggi="$OGGI" -v limite="$LIMITE" \
    -v tol="$GIORNI_TOLLERANZA" \
    -v n="$COL_NOME" -v c="$COL_COGNOME" \
    -v e="$COL_EMAIL" -v s="$COL_SCADENZA" '
NR>1 && $s >= oggi && $s <= limite {
    # Calcola nuova scadenza (data scadenza + giorni tolleranza)
    cmd = "date -d '\''" $s " +" tol " days'\'' +%Y-%m-%d"
    cmd | getline nuova_scadenza
    close(cmd)

    print $e "|" $n "|" $c "|" $s "|" nuova_scadenza
}' "$CSV_FILE" | while IFS="|" read -r email nome cognome scadenza nuova_scadenza
do
    ((conteggio_elaborate++))
    
    # Invia email
    mail -s "Avviso di scadenza certificato medico" "$email" <<EOF
Caro/a $nome $cognome,

il tuo certificato medico è scaduto il $scadenza.
Hai tempo fino al $nuova_scadenza per rinnovarlo prima di perdere
l'accesso ai servizi del centro sportivo.

Grazie per la collaborazione.
EOF
    
    if [[ $? -eq 0 ]]; then
        echo "✓ Email inviata a: $email ($nome $cognome)"
        ((conteggio_inviate++))
    else
        echo "✗ Errore nell'invio a: $email"
        ((conteggio_errori++))
    fi
done

echo ""
echo "════════════════════════════════════════"
echo "RIEPILOGO INVIO EMAIL"
echo "════════════════════════════════════════"
echo "Utenti elaborati:     $conteggio_elaborate"
echo "Email inviate:        $conteggio_inviate"
echo "Email fallite:        $conteggio_errori"
echo "════════════════════════════════════════"
