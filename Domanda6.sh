#legge la temperatura da un file (che simula il sensore) e invia un avviso se scende sotto la soglia critica.

#!/bin/bash

SOGLIA_MINIMA=26
LOG_ALLARMI="allarmi_sensore_piscina.txt"
EMAIL_MANUTENZIONE="centroSportivo@manutenzione.it"
MITTENTE="repartoControlliCS@outlook.it"

echo "--- MONITORAGGIO TEMPERATURA IN CORSO ---"

# generiamo un numero tra 20 e 30, che è la temperatura
TEMP=$((RANDOM % 11 + 20))

echo "Temperatura attuale rilevata: $TEMP°C"

if [ "$TEMP" -lt "$SOGLIA_MINIMA" ]; then #-lt significa minore di
    echo "ALLARME: Temperatura vasca troppo bassa: ($TEMP°C)!"
    echo "Attivazione caldaie di recupero..."
    
    # registra l'allarme nel log degli allarmi
    echo "$(date): ALLARME TEMPERATURA VASCA! Rilevati $TEMP°C." >> "$LOG_ALLARMI"


  #  (
   #   echo "Subject: ALLARME CRITICO: Temperatura Piscina"
    #  echo "To: $EMAIL_MANUTENZIONE"
     # echo "From: $MITTENTE"
    #  echo ""
    #  echo "Attenzione, in data $(date) il sensore piscina IP 192.168.1.200 ha rilevato una temperatura anomala di $TEMP°C."
    #  echo "Richiesto intervento immediato sulle caldaie."
   # ) #| sendmail -t

     echo "Messaggio di allarme inviato al reparto manutenzione -> $EMAIL_MANUTENZIONE."

    
else
    echo "Temperatura ottimale. Nessuna azione richiesta."
fi

echo "Prossimo controllo tra 30 minuti."