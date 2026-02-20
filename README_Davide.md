Analisi degli Script, Tomasini Davide

*****************************************************
Requisiti di Sistema:
Ambiente Bash (Git Bash o Linux).
OpenSSH Server attivo su Windows.
Utente admin_centro configurato sul sistema.
*****************************************************

Gestore Database (Domanda4.sh)
Scopo: Centralizzare i dati degli iscritti provenienti dai db di diverse società (es. Piscina, Palestra, tennis) in un unico database normalizzato.

Funzionamento: Inizializza un file CSV chiamato "centro_sportivo.csv", strutturato su 11 colonne (nom, cognome, servizio...).Effettua la lettura dei file sorgente pulendo i caratteri speciali di Windows (\r).

Logica : Smonta le righe originali e le rimonta inserendo in modo dinamico il nome dello sport dato in input dall'utente e impostando il flag "Ban" su NO di default.

-----------------------------------------------------------------------------------------

Diagnostica termostato (Domanda5.sh)
Scopo: Verificare il funzionamento dei dispositivi IoT della struttura.

Funzionamento:Utilizza il protocollo ICMP (Ping) per verificare la connettività hardware. Il codice implementa una logica di controllo a due livelli: se il dispositivo risponde al ping ma non al servizio web (che ho simulato tramite porta 22), identifica un guasto software. Se il ping fallisce all'inizio, identifica un guasto hardware.
La porta 22 rappresenta lo standard SSH (la uso perchè è già sempre aperta)
L'indirizzo 127.0.0.1 indentifica localhost, la utilizzo come se fosse l'ip del termostato.

Registro errori: Ogni anomalia viene registrata con data e ora nel file log_manutenzione.txt. 

-----------------------------------------------------------------------------------------

Monitoraggio Ambientale (Domanda6.sh)
Scopo: controllare la temperatura della vasca piscina, seguendo un percorso sequenziale

Funzionamento: Il software opera secondo una logica: se i prerequisiti di connettività non sono soddisfatti, il sistema si arresta immediatamente per evitare letture errate:
1. Fase di controllo Hardware 
Lo script non esegue la diagnostica hardware internamente, ma richiama esternamente il codice Domanda5.sh
Controllo Exit Status: Attraverso l'istruzione if ! bash "$SCRIPT_TERMOSTATO", il codice Domanda6.sh cattura il codice di ritorno dello script Domanda5.sh, se la diagnostica fallisce (errore sw o hw), lo script interrompe l'esecuzione segnalando il blocco di sicurezza.
2. Fase di Analisi Dati
Solo dopo aver ricevuto il "via libera" dalla diagnostica, il sistema procede a leggere dal file temperatura_sensore.txt, la temperatura attuale (il file simula il termostato).
In caso di temperatura sotto soglia minima, viene attivata una procedura di emergenza ed inviata una mail alla manutenzione.

Registro errori:gli eventi che non vanno a buon fine vengono salvati nel file allarmi_sensore_piscina.txt.

-----------------------------------------------------------------------------------------

Accesso Remoto SSH (Domanda7.sh)

Scopo: Questo script permette la consultazione remota del db, estraendo le ultime voci inserite in esso, simulando un ambiente Client-Server reale.

Funzionamento: lo script si connette al server centrale (che ospita il database CSV) e recupera in tempo reale le informazioni più recenti senza dover scaricare l'intero file. 
Utilizza il protocollo SSH (Secure Shell), utilizzato per creare un tunnel criptato tra il terminale dell'amministratore e il server.
Per creare la simulazione ho attivato su windows OpenSSH Server, per accettare connessioni remote.
Il comando inviato tramite SSH sfrutta l'interprete PowerShell sul server per gestire i percorsi dei file Windows. (il db l'ho inserito nel percordo C:\gestione\centro_sportivo.csv).
Il codice si connette all'indirizzo 127.0.0.1, se la porta 22 standard SSH è aperta, che indica il server del db (il mio pc), chiede l'autenticazione all'utente Admin_centro, che ha i permessi sul server, poi posso leggere il db.

Gestione errori: Il sistema è configurato per avere OpenSSH sempre attivo. Se l'accesso dovesse fallire, si piò verificare lo stato del servizio tramite PowerShell con Get-Service sshd e contorllare che la porta 22 sia in ascolto. Se il servizio è attivo, gestisce l'autenticazione e il recupero dei dati, altrimenti restituisce un errore di connessione.




#COMANDI DOMANDA 5-7 DA FARE IN POWERSHELL AMMINISTRATORE

# Ferma il servizio immediatamente in ammin
taskkill /F /IM sshd.exe

# Questo comando "accende" effettivamente il server e apre la porta 22
Start-Service sshd

# come è il servizio ssh?
Get-Service sshd 
