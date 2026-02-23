# Progetto Analisi Situazione Reale
**Alessandro - 2026**

Tre script bash per gestire il database di un centro sportivo. Risolvono problemi reali: backup, sicurezza e qualità dei dati.

---

## Il Contesto

Un centro sportivo con ~1000 iscritti che usa:
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
Script completo di gestione backup con menu interattivo che permette di:

**Funzionalità principali:**
1. **Crea backup** - Backup automatici ogni sera alle 22:00, comprime i file (risparmia 75% spazio), tiene solo gli ultimi 7 backup
2. **Vedi backup disponibili** - Lista tutti i backup con data, ora e dimensione
3. **Ripristina backup completo** - Ripristina l'intero database da un backup specifico (NON sovrascrive l'originale, crea un file nuovo per sicurezza)
4. **Cerca utente nel backup** - Cerca utenti specifici nei backup senza ripristinare tutto, supporta ricerca per:
   - ID utente
   - Nome
   - Cognome
   - Email
   - Sport praticato
5. **Visualizza statistiche** - Mostra numero totale backup, spazio occupato, ultimo backup effettuato e storico degli ultimi 5 backup

**File utilizzati:**
- `centro_sportivo.csv` - database da backuppare

**File creati:**
- `backups/centro_sportivo_backup_YYYYMMDD_HHMMSS.tar.gz` - backup compressi
- `logs_backup/backup_auto.log` - log operazioni automatiche con storico completo
- `logs_backup/backup_YYYY-MM-DD.log` - log giornalieri
- `centro_sportivo_ripristino_YYYYMMDD.csv` - quando ripristini un backup completo
- `utente_ripristinato_YYYYMMDD.csv` - quando cerchi e recuperi un singolo utente
- `utenti_trovati_YYYYMMDD.csv` - quando la ricerca trova più utenti

**Modalità d'uso:**
```bash
./Domanda8.sh              # menu interattivo con tutte le funzioni
./Domanda8.sh backup       # backup automatico (per cron o Streamlit)
./Domanda8.sh list         # elenca backup disponibili
./Domanda8.sh stats        # mostra statistiche
./Domanda8.sh search 1 2 "Mario"  # cerca "Mario" per nome nel backup più recente
```

**Rotazione automatica backup:**
Lo script mantiene automaticamente solo gli ultimi 7 backup, cancellando quelli più vecchi per non riempire il disco.

---

### 2. Attacchi Brute-Force SSH

**Il problema:**
Il server riceveva centinaia di tentativi di login SSH da bot che provavano a indovinare username e password.

**Perché è grave:**
Se riescono ad entrare possono rubare i dati personali degli utenti (GDPR!), modificare il database, o installare malware.

**Soluzione: Domanda9.sh**
Script avanzato che analizza i log SSH, conta i tentativi per ogni IP, classifica il pericolo e blocca automaticamente gli attaccanti.

**Funzionalità principali:**
1. **Analisi automatica** - Scansiona i log SSH e conta i tentativi falliti per ogni IP
2. **Classificazione pericolo:**
   - **ALTO** (>10 tentativi) = attacco serio, viene bloccato immediatamente
   - **MEDIO** (6-10) = sospetto, viene bloccato
   - **BASSO** (2-5) = possibile errore di login, viene solo segnalato
3. **Blocco automatico** - **Dopo 5 tentativi falliti** dallo stesso IP, l'indirizzo viene bloccato automaticamente tramite iptables
4. **Sblocco selettivo:**
   - Sblocca un singolo IP specifico
   - Sblocca tutti gli IP bloccati in una volta
5. **Report dettagliato** - Genera report con timestamp, IP, numero tentativi e livello di pericolo

**File utilizzati:**
- `auth.log` - log SSH da analizzare

**File creati:**
- `analisi_ssh/analisi_ssh_YYYYMMDD_HHMMSS.txt` - report completo dell'analisi
- `ip_bloccati.txt` - lista degli IP bloccati con timestamp e motivo

**Come funziona iptables:**
- `iptables` è il firewall di Linux che filtra il traffico di rete
- `-A INPUT` aggiunge una regola per il traffico in entrata
- `-s IP` specifica l'indirizzo IP da bloccare
- `-j DROP` scarta tutti i pacchetti da quell'IP senza rispondere (l'attaccante non sa di essere bloccato)

**Modalità d'uso:**
```bash
sudo ./Domanda9.sh                     # analizza e blocca automaticamente (>5 tentativi)
sudo ./Domanda9.sh sblocca 1.2.3.4    # sblocca un IP specifico
sudo ./Domanda9.sh sblocca tutti       # sblocca tutti gli IP bloccati
```

**Soglia di blocco:**
Lo script blocca automaticamente qualsiasi IP che supera **5 tentativi falliti**. Questa soglia protegge da attacchi brute-force evitando falsi positivi (utenti che sbagliano password).

---

### 3. Dati Corrotti nel CSV

**Il problema:**
Il CSV aveva spesso righe con dati mancanti o errati: ID vuoti, nomi mancanti, email sbagliate, date invalide. Causato da errori dell'applicazione web o importazioni manuali.

**Perché è grave:**
Dati corrotti = non puoi contattare gli utenti, le statistiche sono sbagliate, l'app crasha, violazioni GDPR per dati incompleti.

**Soluzione: Domanda10.sh**
Script intelligente che controlla ogni riga del CSV con 6 controlli diversi, identifica i problemi e tenta il recupero automatico dai backup.

**Controlli effettuati:**
1. **ID vuoto o non numerico** - Ogni utente deve avere un ID univoco
2. **Nome mancante** - Campo obbligatorio
3. **Cognome mancante** - Campo obbligatorio
4. **Email invalida** - Deve contenere @ e avere formato corretto
5. **Data di nascita invalida** - Deve essere in formato YYYY-MM-DD
6. **Numero di campi errato** - Deve avere esattamente 9 campi separati da ;

**Recupero automatico:**
Per ogni riga corrotta, lo script:
1. Cerca nei backup una versione corretta usando:
   - ID (se presente)
   - Nome + Cognome
   - Email
   - Data di nascita
2. Se trova la versione corretta, la recupera automaticamente
3. Se non la trova, la riga viene salvata separatamente per controllo manuale

**File utilizzati:**
- `centro_sportivo.csv` - database da controllare
- `backups/*.tar.gz` - backup dove cercare versioni corrette

**File creati:**
- `centro_sportivo_pulito.csv` - database pulito: solo righe valide + righe recuperate dai backup
- `righe_corrotte.csv` - righe che hanno problemi e non sono state recuperate (per revisione manuale)
- Report dettagliato con statistiche:
  - Righe totali analizzate
  - Righe valide
  - Righe corrotte trovate
  - Righe recuperate dai backup
  - Righe ancora corrotte (da controllare manualmente)

**Modalità d'uso:**
```bash
./Domanda10.sh    # analizza, pulisce e tenta recupero automatico
```

**Risultato:**
Lo script crea un database pulito pronto per l'uso, isolando i problemi che richiedono intervento manuale.

---

## Struttura del Progetto

```
Progetto_Analisi_Situazione_Reale/
├── README.md                          # questo file
├── centro_sportivo.csv                # database (400 utenti fittizi)
├── auth.log                           # log SSH con attacchi simulati
├── Domanda8.sh                        # gestione backup completa
├── Domanda9.sh                        # protezione SSH
├── Domanda10.sh                       # pulizia e recupero dati
├── backups/                           # backup compressi
│   └── centro_sportivo_backup_*.tar.gz
├── logs_backup/                       # log operazioni backup
│   ├── backup_auto.log
│   └── backup_YYYY-MM-DD.log
├── analisi_ssh/                       # report analisi SSH
│   └── analisi_ssh_*.txt
├── ip_bloccati.txt                    # IP bloccati da Domanda9
├── centro_sportivo_pulito.csv         # output Domanda10
└── righe_corrotte.csv                 # righe da controllare manualmente
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
# Backup completo con menu
./Domanda8.sh

# Protezione SSH (richiede sudo)
sudo ./Domanda9.sh

# Pulizia database
./Domanda10.sh
```

**3. (Opzionale) Backup automatico notturno:**
```bash
crontab -e
# aggiungi questa riga:
0 22 * * * cd /percorso/completo/progetto && ./Domanda8.sh backup
```

**4. (Opzionale) Protezione SSH continua:**
```bash
crontab -e
# aggiungi questa riga per controllo ogni ora:
0 * * * * cd /percorso/completo/progetto && sudo ./Domanda9.sh
```

---

## Requisiti

**Necessari:**
- Linux con bash (testato su Ubuntu 22.04 e Debian 11)
- Comandi standard: `tar`, `grep`, `awk`, `cut`, `sort`, `uniq`, `date`

**Per funzioni specifiche:**
- `sudo` e `iptables` per bloccare IP (Domanda9)
- `cron` per automazione (opzionale ma consigliato)

---

## Perché Questi Script Sono Riutilizzabili

**Domanda8:**
- Cambia `CSV_FILE="tuofile.csv"` e funziona con qualsiasi file
- Modifica `tail -n +8` per tenere più/meno di 7 backup
- Funziona da menu interattivo o da linea di comando per automazione

**Domanda9:**
- Cambia `AUTH_LOG="tuolog.log"` per analizzare altri log
- Modifica la soglia di blocco (attualmente 5 tentativi) nella variabile dello script
- Le classificazioni ALTO/MEDIO/BASSO sono personalizzabili
- Funzioni di sblocco singolo o di massa

**Domanda10:**
- Cambia `INPUT_CSV="tuofile.csv"` per altri database
- Aggiungi facilmente nuovi controlli nella funzione `valida_riga()`
- Il sistema di recupero automatico funziona con qualsiasi CSV che abbia ID e campi di ricerca

---

## Integrazione con Streamlit

Gli script sono progettati per funzionare sia da terminale che da interfaccia web Streamlit:

```python
# Esempio integrazione Streamlit
import subprocess

# Crea backup
subprocess.run(['./Domanda8.sh', 'backup'])

# Lista backup
subprocess.run(['./Domanda8.sh', 'list'])

# Cerca utente
subprocess.run(['./Domanda8.sh', 'search', '1', '2', 'Mario'])
```

Vedi `interfaccia_grafica.py` per l'implementazione completa.

---

## Note Tecniche

**Dati di test:**
I dati sono fittizi, creati appositamente per testare gli script:
- `centro_sportivo.csv` = 400 utenti generati con Python
- `auth.log` = 50 righe di tentativi SSH (70% attacchi, 30% legittimi)

**Formato CSV:**
```
ID;Nome;Cognome;Data_Nascita;Email;Sport;Abbonamento;Data_Iscrizione;Ultimo_Accesso
```

**Sicurezza:**
- Domanda8 NON sovrascrive mai l'originale durante i ripristini
- Domanda9 richiede `sudo` per modificare iptables (protezione sistema)
- Domanda10 conserva sempre le righe corrotte in un file separato

**Performance:**
- Backup di 1000 utenti (~200KB) → ~50KB compressi (75% risparmio)
- Analisi log di 10.000 righe → ~2 secondi
- Pulizia CSV 1000 righe con 50 corrotte → ~5 secondi





---

## Autore

Alessandro - 2026
Progetto per corso di Analisi di Situazioni Reali