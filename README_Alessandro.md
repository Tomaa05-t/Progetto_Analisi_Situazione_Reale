# I Miei 3 Script - Centro Sportivo

Progetto per Sistemi Operativi GNU/Linux. 

**Contesto:** Centro sportivo con piscina, palestra e tennis. Circa 1000 iscritti, dati salvati in file CSV.

## Problema 8: Backup Automatico

**Il problema:**  
Il database CSV contiene dati critici (nomi, email, certificati medici, abbonamenti). Se il file si corrompe o viene cancellato per errore, perdiamo tutto.

**Soluzione:**  
Script che ogni sera crea un backup compresso del database e lo salva in una cartella dedicata. Usa timestamp nel nome file e mantiene solo gli ultimi 7 backup (rotazione automatica).

**Uso:**
```bash
./Domanda8.sh
# Oppure automatizza con cron: 0 22 * * * /percorso/Domanda8.sh
```

**Comandi chiave:** `tar -czf` (comprime ~75%), `date +"%Y%m%d_%H%M%S"` (timestamp), `mkdir -p` (crea cartella), `ls -t | tail` (trova vecchi backup)

---

## Problema 9: Rilevamento Attacchi SSH

**Il problema:**  
Il server SSH è esposto su Internet per permettere l'accesso remoto. Questo lo rende bersaglio di attacchi brute-force (migliaia di tentativi password).

**Soluzione:**  
Script che analizza il file di log dove Linux registra gli accessi SSH (`/var/log/auth.log`). Conta quanti tentativi falliti ha fatto ogni IP. Se un IP supera la soglia (default 5), lo segnala come sospetto e classifica la minaccia (MEDIO/ALTO/CRITICO). Salva tutto in `report_ssh/`.

**Uso:**
```bash
./Domanda9.sh auth.log 5
# Il 5 è la soglia (modificabile)
```

**Comandi chiave:** `grep "Failed password"` (filtra tentativi falliti), `awk '{print $(NF-3)}'` (estrae IP), `sort | uniq -c` (conta occorrenze), `awk '$1 >= soglia'` (filtra per soglia)

---

## Problema 10: Pulizia Dati Corrotti

**Il problema:**  
Dati inseriti male: ID vuoto, email mancante, campi incompleti. Questi fanno crashare gli altri script (es: mandare email a campo vuoto).

**Soluzione:**  
Script che legge il CSV riga per riga e controlla se ID ed Email sono presenti. Righe valide vanno nel file pulito, righe corrotte in un file separato con il motivo (ID mancante / Email mancante / Entrambi mancanti). Mostra statistiche e percentuale qualità dati.

**Uso:**
```bash
./Domanda10.sh centro_sportivo.csv pulito.csv
```

**Comandi chiave:** `cut -d',' -f1` (estrae ID - colonna 1), `cut -d',' -f5` (estrae Email - colonna 5), `[ -z "$VAR" ]` (controlla se vuoto), `wc -l` (conta righe)

---

**Requisiti:** Linux/WSL, bash 4.0+, comandi base (grep, awk, cut, tar, gzip, sort, uniq, date)

