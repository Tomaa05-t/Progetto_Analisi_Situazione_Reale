ciao
if abbonamento == "Mensile":
            scadenza_abbonamento = (oggi + timedelta(days=30)).strftime("%Y-%m-%d")
        elif abbonamento == "Trimestrale":
            scadenza_abbonamento = (oggi + timedelta(days=90)).strftime("%Y-%m-%d")
        elif abbonamento == "Semestrale":
            scadenza_abbonamento = (oggi + timedelta(days=180)).strftime("%Y-%m-%d")
        else:  # Annuale
            scadenza_abbonamento = (oggi + timedelta(days=365)).strftime("%Y-%m-%d")