import streamlit as st
import subprocess
import os

st.set_page_config(page_title="Menu Opzioni", layout="centered", initial_sidebar_state="collapsed")

st.markdown("""
    <style>
    .main { padding-top: 2rem; }
    </style>
    """, unsafe_allow_html=True)

# Inizializza lo stato di sessione
if "selected_option" not in st.session_state:
    st.session_state.selected_option = None

st.title("Domande, scegli tra 1 e 10:")

opzioni = [
    "Opzione 1: chi può entrare",
    "Opzione 2: report accessi recenti",
    "Opzione 3: invio email certificati scaduti",
    "Opzione 4: crea un databease di utenti",
    "Opzione 5: controllo termostrato",
    "Opzione 6: allarme acqua",
    "Opzione 7: backup dati giornalieri",
    "Opzione 8: backup automatico",
    "Opzione 9: attacchi ssh",
    "Opzione 10: dati corrotti"
]

def execute_domanda8(azione, backup_idx=None, tipo_ricerca=None, valore_ricerca=None):
    """Esegue le operazioni di backup (Domanda 8)"""
    import tarfile
    from pathlib import Path
    
    CSV_FILE = "centro_sportivo.csv"
    BACKUP_DIR = Path("./backups")
    LOG_DIR = Path("./logs_backup")
    
    try:
        if azione == "crea":
            # Crea backup
            if not Path(CSV_FILE).exists():
                st.error(f"❌ Errore: {CSV_FILE} non trovato")
                return False
            
            from datetime import datetime
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            BACKUP_DIR.mkdir(exist_ok=True)
            LOG_DIR.mkdir(exist_ok=True)
            
            backup_file = BACKUP_DIR / f"centro_sportivo_backup_{timestamp}.tar.gz"
            
            st.info("📦 Creazione backup in corso...")
            with tarfile.open(backup_file, "w:gz") as tar:
                tar.add(CSV_FILE, arcname=CSV_FILE)
            
            # Rotazione backup
            backups = sorted(BACKUP_DIR.glob("centro_sportivo_backup_*.tar.gz"), reverse=True)
            for old_backup in backups[7:]:
                old_backup.unlink()
            
            st.success(f"✅ Backup creato: {backup_file.name}")
            return True
        
        elif azione == "lista":
            # Lista backup
            backups = sorted(BACKUP_DIR.glob("centro_sportivo_backup_*.tar.gz"), reverse=True)
            
            if not backups:
                st.warning("⚠️ Nessun backup trovato")
                return False
            
            st.write("📋 **BACKUP DISPONIBILI:**")
            for i, backup in enumerate(backups, 1):
                size_mb = backup.stat().st_size / (1024 * 1024)
                name_parts = backup.stem.split("_")
                date_str = name_parts[-2]
                time_str = name_parts[-1]
                
                if len(date_str) == 8 and len(time_str) == 6:
                    formatted_date = f"{date_str[6:8]}/{date_str[4:6]}/{date_str[0:4]}"
                    formatted_time = f"{time_str[0:2]}:{time_str[2:4]}:{time_str[4:6]}"
                    st.write(f"{i}. {formatted_date} alle {formatted_time} - {size_mb:.2f} MB")
                else:
                    st.write(f"{i}. {backup.name} - {size_mb:.2f} MB")
            
            return True
        
        elif azione == "ripristina":
            # Ripristina backup
            if backup_idx is None:
                st.error("❌ Seleziona un backup")
                return False
            
            backups = sorted(BACKUP_DIR.glob("centro_sportivo_backup_*.tar.gz"), reverse=True)
            if backup_idx < 0 or backup_idx >= len(backups):
                st.error("❌ Backup non valido")
                return False
            
            backup_scelto = backups[backup_idx]
            date_str = backup_scelto.stem.split("_")[-2]
            output_file = f"centro_sportivo_ripristino_{date_str}.csv"
            
            st.info("📥 Estrazione backup...")
            with tarfile.open(backup_scelto, "r:gz") as tar:
                tar.extractall()
            
            if Path(CSV_FILE).exists():
                import shutil
                shutil.copy(CSV_FILE, output_file)
                num_lines = sum(1 for _ in open(output_file))
                st.success(f"✅ Ripristino riuscito!")
                st.write(f"📄 File creato: **{output_file}** ({num_lines} righe)")
                st.info(f"💡 Per sostituire l'originale: `cp {output_file} {CSV_FILE}`")
                return True
            
            return False
        
        elif azione == "cerca":
            # Cerca utente
            if backup_idx is None or not tipo_ricerca or not valore_ricerca:
                st.error("❌ Parametri mancanti")
                return False
            
            backups = sorted(BACKUP_DIR.glob("centro_sportivo_backup_*.tar.gz"), reverse=True)
            if backup_idx < 0 or backup_idx >= len(backups):
                st.error("❌ Backup non valido")
                return False
            
            backup_scelto = backups[backup_idx]
            
            st.info(f"🔍 Cerco '{valore_ricerca}' nel campo '{tipo_ricerca}'...")
            
            try:
                with tarfile.open(backup_scelto, "r:gz") as tar:
                    f = tar.extractfile(CSV_FILE)
                    if not f:
                        st.error("❌ File CSV non trovato nel backup")
                        return False
                    
                    lines = f.read().decode('utf-8').split('\n')
                    header = lines[0]
                    
                    # DEBUG: Mostra info sul file
                    st.write(f"📋 **Debug Info:**")
                    st.write(f"- Totale righe nel backup: {len(lines)}")
                    st.write(f"- Header: `{header}`")
                    st.write(f"- Prima riga dati: `{lines[1] if len(lines) > 1 else 'Nessuna'}`")
                    
                    risultati = []
                    
                    tipo_map = {"ID": 0, "Nome": 1, "Cognome": 2, "Email": 4, "Sport": 5}
                    col_idx = tipo_map.get(tipo_ricerca)
                    
                    if col_idx is None:
                        st.error("❌ Tipo ricerca non valido")
                        return False
                    
                    st.write(f"- Cerco nella colonna index: {col_idx}")
                    
                    # Converti il valore cercato in minuscolo per ricerca case-insensitive
                    valore_lower = valore_ricerca.lower()
                    
                    righe_valide = 0
                    for line in lines[1:]:
                        if not line.strip():
                            continue
                        righe_valide += 1
                        parts = line.split(';')
                        
                        # DEBUG: Mostra alcune righe
                        if righe_valide <= 3:
                            st.write(f"- Riga {righe_valide}: {len(parts)} colonne - Colonna {col_idx}: `{parts[col_idx] if len(parts) > col_idx else 'N/A'}`")
                        
                        if len(parts) > col_idx:
                            # Ricerca parziale case-insensitive
                            campo_valore = parts[col_idx].lower()
                            if valore_lower in campo_valore:
                                risultati.append(line)
                    
                    st.write(f"- Righe valide analizzate: {righe_valide}")
                    st.write(f"- Risultati trovati: {len(risultati)}")
                    
                    if not risultati:
                        st.warning(f"❌ Nessun risultato trovato per '{valore_ricerca}'")
                        st.info("💡 Suggerimento: Prova a cercare con meno lettere (es. 'mar' invece di 'Mario')")
                        return False
                    
                    date_str = backup_scelto.stem.split("_")[-2]
                    
                    if len(risultati) == 1:
                        output_file = f"utente_ripristinato_{date_str}.csv"
                        with open(output_file, 'w') as f:
                            f.write(header + '\n')
                            f.write(risultati[0] + '\n')
                        
                        st.success(f"✅ Trovato 1 utente!")
                        parts = risultati[0].split(';')
                        st.write(f"**ID:** {parts[0] if len(parts) > 0 else 'N/A'}")
                        st.write(f"**Nome:** {parts[1] if len(parts) > 1 else 'N/A'} {parts[2] if len(parts) > 2 else 'N/A'}")
                        st.write(f"**Email:** {parts[4] if len(parts) > 4 else 'N/A'}")
                        st.write(f"**Sport:** {parts[5] if len(parts) > 5 else 'N/A'}")
                    else:
                        output_file = f"utenti_trovati_{date_str}.csv"
                        with open(output_file, 'w') as f:
                            f.write(header + '\n')
                            for riga in risultati:
                                f.write(riga + '\n')
                        
                        st.success(f"✅ Trovati {len(risultati)} utenti")
                        for i, riga in enumerate(risultati, 1):
                            parts = riga.split(';')
                            if len(parts) > 4:
                                st.write(f"{i}. {parts[0]} | {parts[1]} {parts[2]} | {parts[4]}")
                    
                    st.write(f"📄 Salvati in: **{output_file}**")
                    return True
            except Exception as e:
                st.error(f"❌ Errore: {str(e)}")
                import traceback
                st.code(traceback.format_exc())
                return False
        
        elif azione == "stats":
            # Statistiche
            backups = sorted(BACKUP_DIR.glob("centro_sportivo_backup_*.tar.gz"), reverse=True)
            
            st.write("📊 **STATISTICHE BACKUP:**")
            st.write(f"**Numero di backup:** {len(backups)}")
            
            if backups:
                total_size = sum(b.stat().st_size for b in backups) / (1024 * 1024)
                st.write(f"**Spazio totale:** {total_size:.2f} MB")
                
                name_parts = backups[0].stem.split("_")
                date_str = name_parts[-2]
                time_str = name_parts[-1]
                if len(date_str) == 8:
                    formatted_date = f"{date_str[6:8]}/{date_str[4:6]}/{date_str[0:4]}"
                    formatted_time = f"{time_str[0:2]}:{time_str[2:4]}:{time_str[4:6]}"
                    st.write(f"**Ultimo backup:** {formatted_date} alle {formatted_time}")
            
            st.write("")
            st.write("📋 **ULTIMI 5 BACKUP:**")
            if (LOG_DIR / "backup_auto.log").exists():
                with open(LOG_DIR / "backup_auto.log", 'r') as f:
                    lines = f.readlines()
                    for line in lines[-5:]:
                        st.write(f"  {line.strip()}")
            else:
                st.write("  Nessun log disponibile")
            
            return True
    
    except Exception as e:
        st.error(f"❌ Errore: {str(e)}")
        return False

def execute_domanda2(data_inizio, data_fine, tipo_report):
    """Esegue il report accessi (Domanda 2) con date specifiche"""
    import csv
    from datetime import datetime
    
    CSV_FILE = "centro_sportivo.csv"
    CSV_FILE2 = "accessi_orario.csv"
    
    try:
        if tipo_report == "1":
            # Opzione 1: Ultimi accessi
            output1 = "accessi_ultimi.csv"
            
            with open(CSV_FILE, 'r', encoding='utf-8') as f:
                reader = csv.reader(f, delimiter=';')
                rows = list(reader)
            
            with open(output1, 'w', encoding='utf-8', newline='') as f:
                f.write("Nome;Cognome;Ultimo_Accesso;Sport;Abbonamento\n")
                
                conta = 0
                for row in rows[1:]:
                    if len(row) > 8:
                        data_accesso = row[8]
                        if data_inizio <= data_accesso <= data_fine:
                            f.write(f"{row[1]};{row[2]};{row[8]};{row[5]};{row[6]}\n")
                            conta += 1
            
            st.success(f"✓ Ricerca completata!")
            st.write(f"**Utenti con ultimi accessi dal {data_inizio} al {data_fine}: {conta}**")
            st.write(f"Risultati salvati in: `{output1}`")
            
            with open(output1, 'r', encoding='utf-8') as f:
                st.text_area("Anteprima risultati:", value=f.read(), height=250, disabled=True)
        
        elif tipo_report == "2":
            # Opzione 2: Accessi dettagliati
            output2 = "accessi_dettagliati.csv"
            
            with open(CSV_FILE2, 'r', encoding='utf-8') as f:
                reader = csv.reader(f, delimiter=';')
                rows = list(reader)
            
            with open(output2, 'w', encoding='utf-8', newline='') as f:
                f.write("ID;Nome;Cognome;Data_Accesso;Orario_Entrata;Orario_Uscita\n")
                
                conta = 0
                for row in rows[1:]:
                    if len(row) >= 5:
                        f.write(f"{row[0]};{row[1]};{row[2]};{data_inizio};{row[3]};{row[4]}\n")
                        conta += 1
            
            st.success(f"✓ Generazione completata!")
            st.write(f"**Accessi dettagliati generati dal {data_inizio} al {data_fine}: {conta}**")
            st.write(f"Risultati salvati in: `{output2}`")
            
            with open(output2, 'r', encoding='utf-8') as f:
                st.text_area("Anteprima risultati:", value=f.read(), height=250, disabled=True)
    
    except FileNotFoundError as e:
        st.error(f"❌ Errore: file non trovato - {str(e)}")
    except Exception as e:
        st.error(f"❌ Errore durante l'elaborazione: {str(e)}")

def execute_script(option_num):
    """Esegue lo script bash corrispondente all'opzione"""
    
    # Definisci i file bash da eseguire
    script_files = {
        1: ("bash", "Domanda1.sh"),
        2: ("bash", "Domanda2.sh"),
        3: ("bash", "Domanda3.sh"),
        4: ("bash", "Domanda4_generaDBcentro.sh"),
        5: ("bash", "Domanda5.sh"),
        6: ("bash", "Domanda6.sh"),
        7: ("bash", "Domanda7.sh"),
        8: ("bash", "Domanda8.sh"),
        9: ("bash", "Domanda9.sh"),
        10: ("bash", "Domanda10.sh")
    }
    
    script_info = script_files.get(option_num)
    
    if script_info:
        script_type, script_file = script_info
        try:
            st.info(f"Esecuzione azione {option_num}...")
            
            # Esegui lo script appropriato (bash o python)
            if script_type == "bash":
                cmd = ["bash", script_file]
            else:  # python3
                cmd = ["python3", script_file]
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=60
            )
            
            # Mostra il risultato
            if result.returncode == 0:
                st.success(f"✓ Opzione {option_num} completata con successo!")
                if result.stdout:
                    st.text_area("Output:", value=result.stdout, height=200, disabled=True)
            else:
                st.error(f"✗ Errore durante l'esecuzione dell'opzione {option_num}")
                if result.stderr:
                    st.text_area("Errore:", value=result.stderr, height=150, disabled=True)
                    
        except FileNotFoundError:
            st.error(f"Script '{script_file}' non trovato. Assicurati che sia nella stessa directory.")
        except subprocess.TimeoutExpired:
            st.error("Lo script ha impiegato troppo tempo (timeout dopo 60 secondi)")
        except Exception as e:
            st.error(f"Errore durante l'esecuzione: {str(e)}")
    else:
        st.error("Opzione non valida!")

# Crea i pulsanti per ogni opzione
cols = st.columns(2)
for i, opzione in enumerate(opzioni, 1):
    col = cols[(i - 1) % 2]
    with col:
        if st.button(opzione, key=f"btn_{i}", use_container_width=True):
            st.session_state.selected_option = i

# Mostra l'interfaccia dell'opzione selezionata
if st.session_state.selected_option is not None:
    st.divider()
    
    if st.session_state.selected_option == 2:  # Domanda 2 ha un'interfaccia speciale
        st.subheader("📊 Report Accessi Centro Sportivo")
        
        with st.form("domanda2_form"):
            col1, col2 = st.columns(2)
            with col1:
                data_inizio = st.date_input("📅 Data inizio", key="date_start")
            with col2:
                data_fine = st.date_input("📅 Data fine", key="date_end")
            
            tipo_report = st.radio(
                "Scegli il tipo di report:",
                ["1", "2"],
                format_func=lambda x: "Ultimi accessi registrati" if x == "1" else "Accessi dettagliati ora per ora",
                key="report_type"
            )
            
            submitted = st.form_submit_button("🔍 Genera Report", use_container_width=True)
            
            if submitted:
                # Converti le date al formato YYYY-MM-DD
                data_inizio_str = data_inizio.strftime("%Y-%m-%d")
                data_fine_str = data_fine.strftime("%Y-%m-%d")
                
                # Validazione
                if data_fine < data_inizio:
                    st.error("❌ La data di fine deve essere successiva o uguale alla data di inizio")
                else:
                    execute_domanda2(data_inizio_str, data_fine_str, tipo_report)
    
    elif st.session_state.selected_option == 8:  # Domanda 8 ha menu speciale
        st.subheader("📦 Backup Database Centro Sportivo")
        
        azione = st.radio(
            "Scegli operazione:",
            ["crea", "lista", "ripristina", "cerca", "stats"],
            format_func=lambda x: {
                "crea": "📦 Crea backup",
                "lista": "📋 Vedi backup disponibili",
                "ripristina": "📥 Ripristina backup completo",
                "cerca": "🔍 Cerca utente nel backup",
                "stats": "📊 Visualizza statistiche"
            }[x],
            key="domanda8_azione"
        )
        
        if azione == "crea":
            if st.button("📦 Crea Backup Ora", use_container_width=True, key="btn_crea_backup"):
                execute_domanda8("crea")
        
        elif azione == "lista":
            if st.button("📋 Mostra Backup", use_container_width=True, key="btn_lista_backup"):
                execute_domanda8("lista")
        
        elif azione == "ripristina":
            from pathlib import Path
            BACKUP_DIR = Path("./backups")
            backups = sorted(BACKUP_DIR.glob("centro_sportivo_backup_*.tar.gz"), reverse=True)
            
            if not backups:
                st.warning("⚠️ Nessun backup disponibile")
            else:
                backup_options = {}
                for i, backup in enumerate(backups):
                    name_parts = backup.stem.split("_")
                    date_str = name_parts[-2]
                    time_str = name_parts[-1]
                    if len(date_str) == 8:
                        formatted_date = f"{date_str[6:8]}/{date_str[4:6]}/{date_str[0:4]}"
                        formatted_time = f"{time_str[0:2]}:{time_str[2:4]}:{time_str[4:6]}"
                        backup_options[i] = f"{formatted_date} alle {formatted_time}"
                
                selected_backup = st.selectbox(
                    "Seleziona backup da ripristinare:",
                    options=list(backup_options.keys()),
                    format_func=lambda x: backup_options[x],
                    key="ripristina_backup_select"
                )
                
                if st.button("📥 Ripristina", use_container_width=True, key="btn_ripristina"):
                    execute_domanda8("ripristina", backup_idx=selected_backup)
        
        elif azione == "cerca":
            from pathlib import Path
            BACKUP_DIR = Path("./backups")
            backups = sorted(BACKUP_DIR.glob("centro_sportivo_backup_*.tar.gz"), reverse=True)
            
            if not backups:
                st.warning("⚠️ Nessun backup disponibile")
            else:
                backup_options = {}
                for i, backup in enumerate(backups):
                    name_parts = backup.stem.split("_")
                    date_str = name_parts[-2]
                    time_str = name_parts[-1]
                    if len(date_str) == 8:
                        formatted_date = f"{date_str[6:8]}/{date_str[4:6]}/{date_str[0:4]}"
                        formatted_time = f"{time_str[0:2]}:{time_str[2:4]}:{time_str[4:6]}"
                        backup_options[i] = f"{formatted_date} alle {formatted_time}"
                
                # NON usare form - causa reset dello stato
                selected_backup = st.selectbox(
                    "Seleziona backup:",
                    options=list(backup_options.keys()),
                    format_func=lambda x: backup_options[x],
                    key="cerca_backup_select"
                )
                
                tipo = st.radio(
                    "Cerca per:",
                    ["ID", "Nome", "Cognome", "Email", "Sport"],
                    key="tipo_ricerca"
                )
                
                valore = st.text_input("Cosa cerchi?", key="valore_ricerca")
                
                if st.button("🔍 Cerca", use_container_width=True, key="btn_cerca_utente"):
                    if valore:
                        execute_domanda8("cerca", backup_idx=selected_backup, 
                                       tipo_ricerca=tipo, valore_ricerca=valore)
                    else:
                        st.error("❌ Inserisci un valore da cercare")
        
        elif azione == "stats":
            if st.button("📊 Mostra Statistiche", use_container_width=True, key="btn_stats"):
                execute_domanda8("stats")
    
    else:
        # Esegui script bash per le altre opzioni
        execute_script(st.session_state.selected_option)
    
    st.divider()
    
    if st.button("← Torna al Menu", use_container_width=True):
        st.session_state.selected_option = None
        st.rerun()

else:
    st.info("💡 Seleziona un'opzione per eseguire l'azione corrispondente")