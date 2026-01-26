#domanda per inviare la e-mail agli utenti con certificato scaduto
#!/bin/bash
oggi=$(date +%F)
lim_data=$(date -d "+30 days" +%F)
nuovo_limite_cerificato=$(date "9 days" +%F)
awk -F, 'NR>1 {if ($8 >= "'"$oggi"'" && $8 <= "'"$lim_data"'") print $5}' centro_sportivo.csv | while read email; do
  echo "Attenxione: Avviso di Scadenza del Certificato Medico
To: $email
Caro $2 $3,   
il tuo certificato medico è scaduto. Lei ha ancora tempo fino al $8+$nuovo_limite_cerificato prima di perdere l'accesso ai servizi del centro sportivo. Per favore, rinnova il certificato per continuare a utilizzare i servizi.
Grazie per la collaborazione." | sendmail -t
done 
