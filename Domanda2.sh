#rilevamento accesssi centro sportivo
#!/bin/bash
oggi=$(date +%F)
lim_data=$(date -d "-14 days" +%F)
awk -F, 'NR>1 {if ($9 < "'"$oggi"' && $9 > "'"$lim_data"'") print ($2,$3 "ha fatto l'ultimo accesso in data " $9) }' centro_sportivo.csv > accessi_recenti_di_settimana.csv