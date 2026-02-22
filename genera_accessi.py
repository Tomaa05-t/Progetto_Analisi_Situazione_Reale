import csv
import random
from datetime import datetime, timedelta

# Leggi il file CSV
input_file = 'centro_sportivo.csv'
output_file = 'accessi_orario.csv'

# Parametri
ora_inizio = 9  # 9:00
ora_fine = 22   # 22:00
max_ore_differenza = 4  # massimo 4 ore tra entrata e uscita

def genera_orario_casuale(ora_min, ora_max):
    """Genera un orario casuale in formato HH:MM"""
    ora = random.randint(ora_min, ora_max - 1)
    minuto = random.randint(0, 59)
    return f"{ora:02d}:{minuto:02d}"

def tempo_a_minuti(orario_str):
    """Converte un orario HH:MM in minuti dal mezzanotte"""
    ore, minuti = map(int, orario_str.split(':'))
    return ore * 60 + minuti

def minuti_a_tempo(minuti):
    """Converte minuti dal mezzanotte in formato HH:MM"""
    ore = minuti // 60
    mins = minuti % 60
    return f"{ore:02d}:{mins:02d}"

# Leggi il file di input e scrivi il file di output
accessi = []

with open(input_file, 'r', encoding='utf-8') as infile:
    reader = csv.DictReader(infile, delimiter=';')
    
    for row in reader:
        id_utente = row['ID']
        nome = row['Nome']
        cognome = row['Cognome']
        
        # Genera orario di entrata casuale
        orario_entrata = genera_orario_casuale(ora_inizio, ora_fine)
        entrata_minuti = tempo_a_minuti(orario_entrata)
        
        # Genera orario di uscita casuale (max 4 ore dopo l'entrata)
        max_minuti = min(
            entrata_minuti + (max_ore_differenza * 60),  # max 4 ore dopo entrata
            (ora_fine * 60) - 1  # non oltre le 22:00
        )
        min_minuti = entrata_minuti + 1  # almeno 1 minuto dopo l'entrata
        
        uscita_minuti = random.randint(min_minuti, max_minuti)
        orario_uscita = minuti_a_tempo(uscita_minuti)
        
        accessi.append({
            'ID': id_utente,
            'Nome': nome,
            'Cognome': cognome,
            'Orario_Entrata': orario_entrata,
            'Orario_Uscita': orario_uscita
        })

# Scrivi il file di output
with open(output_file, 'w', newline='', encoding='utf-8') as outfile:
    fieldnames = ['ID', 'Nome', 'Cognome', 'Orario_Entrata', 'Orario_Uscita']
    writer = csv.DictWriter(outfile, fieldnames=fieldnames, delimiter=';')
    
    writer.writeheader()
    writer.writerows(accessi)

print(f"✓ File generato con successo: {output_file}")
print(f"✓ Totale utenti: {len(accessi)}")
print(f"✓ Orari compresi tra {ora_inizio:02d}:00 e {ora_fine:02d}:00")
print(f"✓ Differenza massima entrata-uscita: {max_ore_differenza} ore")
