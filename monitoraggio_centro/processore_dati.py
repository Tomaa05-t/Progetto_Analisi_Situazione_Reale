import csv
import os
from datetime import datetime

# Importiamo i dati dal file torrello.py
# Nota: torrello.py deve contenere una lista di dizionari chiamata 'ingressi'
try:
    from torrello import ingressi
except ImportError:
    print("Errore: Assicurati che torrello.py esista e contenga la variabile 'ingressi'.")
    ingressi = []

def genera_report():
    # Otteniamo la data di oggi per il nome del file
    oggi = datetime.now().strftime("%Y-%m-%d")
    nome_file = f"accessi_giornalieri/report_{oggi}.csv"
    
    # Assicuriamoci che la cartella di destinazione esista
    os.makedirs("accessi_giornalieri", exist_ok=True)
    
    campi = ['id', 'nome', 'cognome', 'ora_entrata', 'ora_uscita']
    
    try:
        with open(nome_file, mode='w', newline='', encoding='utf-8') as file_csv:
            scrittore = csv.DictWriter(file_csv, fieldnames=campi)
            scrittore.writeheader()
            
            for persona in ingressi:
                # Scriviamo solo i campi richiesti
                scrittore.writerow({
                    'id': persona.get('id'),
                    'nome': persona.get('nome'),
                    'cognome': persona.get('cognome'),
                    'ora_entrata': persona.get('ora_entrata'),
                    'ora_uscita': persona.get('ora_uscita')
                })
        print(f"Report generato con successo: {nome_file}")
    except Exception as e:
        print(f"Si è verificato un errore: {e}")

if __name__ == "__main__":
    genera_report()