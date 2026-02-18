# Progetto Analisi Situazione Reale
**Alessandro - 2026**

Tre script bash per gestire il database di un centro sportivo. Risolvono problemi reali: backup, sicurezza e qualità dei dati.

---

## Il Contesto

Un centro sportivo con ~400 iscritti che usa:
- Un database CSV per gestire gli utenti
- Un server Linux per il sistema informatico
- Accesso SSH per l'amministrazione

Ho trovato tre problemi che andavano risolti con script automatici.

---

## I Tre Problemi

### 1. Nessun Backup del Database

**Il problema:**
Il database non aveva backup. Se il file si corrompeva o veniva cancellato per errore, tutti i dati erano persi.

**Perché è grave:**
Perdere il database = non poter più contattare gli utenti, perdere gli abbonamenti, perdere la fatturazione.

**Soluzione: Domanda8.sh**
Script che fa backup automatici ogni sera alle 22:00, comprime i file (risparmia 75% spazio), tiene solo gli ultimi 7 backup, e permette di cercare utenti specifici nei backup senza ripristinare tutto.

```bash
./Domanda8.sh         # menu interattivo
./Domanda8.sh auto    # backup automatico (per cron)
```

---

### 2. Attacchi Brute-Force SSH

**Il problema:**
Il server riceveva centinaia di tentativi di login SSH da bot che provavano a indovinare username e password.

**Perché è grave:**
Se riescono ad entrare possono rubare i dati personali degli utenti (GDPR!), modificare il database, o installare malware.

**Soluzione: Domanda9.sh**
Script che analizza i log SSH, conta i tentativi per ogni IP, classifica il pericolo in ALTO/MEDIO/BASSO, e blocca automaticamente con iptables gli IP sopra 5 tentativi.

```bash
sudo ./Domanda9.sh                    # analizza e blocca
sudo ./Domanda9.sh sblocca 1.2.3.4   # sblocca un IP
```

**Classificazione:**
- **ALTO** (>10 tentativi) = attacco serio
- **MEDIO** (5-10) = sospetto
- **BASSO** (2-5) = forse si è sbagliato

---

### 3. Dati Corrotti nel CSV

**Il problema:**
Il CSV aveva spesso righe con dati mancanti: ID vuoti, nomi mancanti, email sbagliate. Causato da errori dell'applicazione web o importazioni manuali.

**Perché è grave:**
Dati corrotti = non puoi contattare gli utenti, le statistiche sono sbagliate, l'app crasha.

**Soluzione: Domanda10.sh**
Script che controlla ogni riga del CSV (6 controlli diversi), trova quelle corrotte, e prova a recuperarle automaticamente dai backup usando nome e cognome.

```bash
./Domanda10.sh
```

**Genera:**
- `centro_sportivo_pulito.csv` = solo righe valide + quelle recuperate
- `righe_corrotte.csv` = righe originali con problemi

---

## Struttura del Progetto

```
Progetto_Analisi_Situazione_Reale/
├── README.md                 
├── centro_sportivo.csv       # database (400 utenti fittizi)
├── auth.log                  # log SSH con attacchi simulati
├── Domanda8.sh               # backup
├── Domanda9.sh               # analisi SSH
├── Domanda10.sh              # pulizia dati
├── backups/                  
├── logs_backup/              
└── analisi_ssh/              
```

---

## Come Usare

**1. Clona il repository:**
```bash
git clone [URL]
cd Progetto_Analisi_Situazione_Reale
chmod +x *.sh
```

**2. Prova gli script:**
```bash
./Domanda8.sh              # backup
sudo ./Domanda9.sh         # analisi SSH (serve sudo)
./Domanda10.sh             # pulizia CSV
```

**3. (Opzionale) Backup automatico:**
```bash
crontab -e
# aggiungi: 0 22 * * * cd /percorso/progetto && ./Domanda8.sh auto
```

---

## Requisiti

**Necessari:**
- Linux con bash
- Comandi standard: `tar`, `grep`, `awk`, `cut`, `sort`, `uniq`

**Per funzioni specifiche:**
- `sudo` e `iptables` per bloccare IP (Domanda9)
- `cron` per backup automatici (Domanda8)

---

## Perché Questi Script Sono Riutilizzabili

**Domanda8:**
Cambia `CSV_FILE="tuofile.csv"` e funziona con qualsiasi file. Puoi modificare quanti backup tenere cambiando una variabile.

**Domanda9:**
Cambia `AUTH_LOG="tuolog.log"` per analizzare altri log. Le soglie ALTO/MEDIO/BASSO sono personalizzabili.

**Domanda10:**
Cambia `INPUT_CSV="tuofile.csv"` e funziona con qualsiasi CSV. Puoi aggiungere altri controlli facilmente.

---

## Note Tecniche

I dati sono fittizi, creati appositamente per testare gli script:
- `centro_sportivo.csv` = 400 utenti generati con Python
- `auth.log` = 50 righe di tentativi SSH (70% attacchi, 30% legittimi)

Testato su Ubuntu 22.04 e Debian 11.

