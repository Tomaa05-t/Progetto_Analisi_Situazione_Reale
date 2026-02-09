import random
from datetime import datetime, timedelta

# Configurazione del file
OUTPUT_FILE = "iscritti_piscina.csv"
NUM_UTENTI = 400

# Liste per la generazione casuale kkkkk
nomi = ["Marco", "Giulia", "Davide", "Sara", "Alessandro", "Elena", "Cristiano", "Chiara", "Matteo", "Valentina", "Riccardo", "Beatrice", "Simone", "Alice"]
cognomi = ["Rossi", "Bianchi", "Verdi", "Ferrari", "Russo", "Piccoli", "Romano", "Gallo", "Conti", "Marino", "Zappa", "Ricci", "Moretti", "Colombo"]
servizi = ["Piscina"]
abbonamenti = [ "Mensile", "Trimestrale", "Semestrale", "Annuale", ]
domini = ["gmail.com", "outlook.it", "yahoo.com", "icloud.com"]
ban = ["sì", "no"]

def genera_data_casuale(inizio, fine):
    delta = fine - inizio
    random_giorno = random.randrange(delta.days)
    return inizio + timedelta(days=random_giorno)

# Date di riferimento
oggi = datetime.now()
inizio_2025 = datetime(2025, 1, 1)
fine_2028 = datetime(2028, 12, 31)
fine_2015 = datetime(2015, 12, 31)
inizio_1946 = datetime(1946, 1, 1)

print(f"Generazione di {NUM_UTENTI} utenti in corso...")

with open(OUTPUT_FILE, mode="w", encoding="utf-8") as f:
    # Intestazione (Header)
    f.write("ID,Nome,Cognome,Data_Nascita,Email,Abbonamento,Scadenza_Certificato,Ultimo_Accesso,Scadenza_Abbonamento\n")
    
    for i in range(1, NUM_UTENTI + 1):
        nome = random.choice(nomi)
        cognome = random.choice(cognomi)
        servizio = random.choice(servizi)
        abbonamento = random.choice(abbonamenti)
        dominio = random.choice(domini)

        # Generazione Email (es: marco.rossi@gmail.com)
        # .lower() serve per avere tutto in minuscolo
        email = f"{nome.lower()}.{cognome.lower()}{random.randint(1,99)}@{dominio}"
        
        # Certificato scade nel futuro (tra oggi e fine 2028)
        scadenza_cert = genera_data_casuale(oggi, fine_2028).strftime("%Y-%m-%d")
        
        # Ultimo accesso nel passato (durante il 2025/2026)
        ultimo_acc = genera_data_casuale(inizio_2025, oggi).strftime("%Y-%m-%d")

        # Generazione data di nascita
        data_nascita = genera_data_casuale(inizio_1946, fine_2015).strftime("%Y-%m-%d")
        
        #generazione scadenxa abbonamento
        scadenza_abbonamento = genera_data_casuale(inizio_2025, fine_2028).strftime("%Y-%m-%d")

        #ban = random.random() < 0.05

        # Scrittura riga
        f.write(f"{i},{nome},{cognome},{data_nascita},{email},{abbonamento},{scadenza_cert},{ultimo_acc},{scadenza_abbonamento}\n")

print(f"Successo! Il file '{OUTPUT_FILE}' è stato creato.")