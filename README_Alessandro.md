
Tre script bash per gestire il database del centro sportivo. Li ho scritti per automatizzare il backup, analizzare i log SSH e pulire i dati corrotti.


# Gli script

# Domanda8.sh - Backup database
Gestisce i backup del file `centro_sportivo.csv`. Ha un menu interattivo con 4 opzioni e una modalità automatica per cron.

bash
./Domanda8.sh         # apre il menu
./Domanda8.sh auto    # backup automatico (per cron)
```

Dal menu puoi:
- creare un backup manuale
- vedere la lista dei backup disponibili
- ripristinare il database da un backup
- cercare un utente specifico nei backup

I backup vengono salvati in `./backups/` come file `.tar.gz` e vengono tenuti solo gli ultimi 7 (i più vecchi vengono cancellati automaticamente).

Per configurare il backup automatico ogni sera alle 22:00:
bash
sudo apt-get install -y cron && sudo service cron start
crontab -e
# aggiungi questa riga:
0 22 * * * cd /workspaces/Progetto_Analisi_Situazione_Reale && ./Domanda8.sh auto




# Domanda9.sh - Analisi attacchi SSH
Analizza il file `auth.log` e trova i tentativi di login SSH falliti. Classifica gli IP per livello di pericolo e blocca automaticamente quelli più aggressivi.

```bash
sudo ./Domanda9.sh                    # analizza e blocca
sudo ./Domanda9.sh sblocca 1.2.3.4   # sblocca un IP specifico
sudo ./Domanda9.sh sblocca tutti      # sblocca tutti gli IP
```

Gli IP vengono divisi in tre categorie:
- **ALTO** → più di 10 tentativi
- **MEDIO** → tra 5 e 10 tentativi
- **BASSO** → tra 2 e 5 tentativi

Gli IP con più di 5 tentativi vengono bloccati automaticamente con `iptables`. Il report viene salvato nella cartella `analisi_ssh/`.

---

### Domanda10.sh - Pulizia dati corrotti
Controlla il CSV e trova le righe con campi mancanti (ID, Nome, Cognome, Email, ecc.). Per ogni riga corrotta prova a recuperare i dati dal backup più recente.

```bash
./Domanda10.sh
```

Genera due file:
- `centro_sportivo_pulito.csv` → solo le righe valide (più quelle recuperate dai backup)
- `righe_corrotte.csv` → le righe originali con i dati mancanti

---

## Struttura cartelle

```
Progetto_Analisi_Situazione_Reale/
├── centro_sportivo.csv       # database principale
├── Domanda8.sh               # script backup
├── Domanda9.sh               # script analisi SSH
├── Domanda10.sh              # script pulizia CSV
├── auth.log                  # log SSH da analizzare
├── backups/                  # backup compressi .tar.gz
├── logs_backup/              # log dei backup automatici
└── analisi_ssh/              # report analisi SSH
```



# Requisiti

- Bash
- `tar`, `grep`, `awk`, `cut` (già presenti su Linux)
- `iptables` e `sudo` per bloccare gli IP (solo Domanda9)
- `cron` per i backup automatici (solo Domanda8)