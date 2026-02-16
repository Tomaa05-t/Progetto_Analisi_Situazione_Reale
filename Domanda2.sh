#!/bin/bash
# rilevamento accessi negli ultimi x giorni mettere durrsts

input="centro_sportivo.csv"
output="accessi_recenti.csv"
input2="accessi_orario.csv"

read -p "Inserisci la data limite (YYYY-MM-DD): " limit

if date -d "$limit" >/dev/null 2>&1; then
    echo "Data valida"
else
    echo "Data NON valida"
    exit 1
fi

oggi=$(date +%Y-%m-%d)
lim_data=$(date -d "$limit" +%Y-%m-%d)

awk -F';' -v oggi="$oggi" -v lim_data="$lim_data" '
NR>1 {
    if ($9 < oggi && $9 > lim_data)
        print $2, $3 " ha fatto l ultimo accesso in data ", $9
}' "$input" > "$output"
echo "Utenti con accessi dal $lim_data al $oggi sono salvati in $output e sono"
wc -l < "$output"
