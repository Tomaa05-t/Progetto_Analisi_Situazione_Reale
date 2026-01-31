import tkinter as tk
from tkinter import messagebox
import subprocess


class MenuGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("Menu Opzioni")
        self.root.geometry("500x800")
        self.root.config(bg="#f0f0f0")
        
        
        title = tk.Label(
            root,
            text="Domande, scegli tra 1 e 10:",
            font=("Arial", 18, "bold"),
            bg="#f0f0f0",
            fg="#333"
        )
        title.pack(pady=20)
        
        frame = tk.Frame(root, bg="#f0f0f0")
        frame.pack(pady=10, padx=20, fill=tk.BOTH, expand=True)
        
        
        opzioni = [
            "Opzione 1: chi può entrare",
            "Opzione 2: report accessi recenti",
            "Opzione 3: invio email certificati scaduti",
            "Opzione 4: crea un databease di utenti",
            "Opzione 5",
            "Opzione 6",
            "Opzione 7",
            "Opzione 8",
            "Opzione 9",
            "Opzione 10"
        ]
        
        for i, opzione in enumerate(opzioni, 1):
            btn = tk.Button(
                frame,
                text=opzione,
                command=lambda num=i: self.handle_option(num),
                font=("Arial", 12),
                bg="#4CAF50",
                fg="white",
                relief=tk.RAISED,
                padx=10,
                pady=10
            )
            btn.pack(fill=tk.X, pady=5)
        

        btn_exit = tk.Button(
            root,
            text="fine",
            command=root.quit,
            font=("Arial", 11),
            bg="#f44336",
            fg="white",
            padx=10,
            pady=8
        )
        btn_exit.pack(pady=10)
    
    def handle_option(self, option):
        """Gestisce le 10 opzioni con un case statement"""
        match option:
            case 1:
                messagebox.showinfo("Risultato", "Hai scelto l'Opzione 1!\nEsecuzione azione 1...")
                subprocess.run(["bash", "Domanda1.sh"], check=True)
                messagebox.showinfo("Accesso negato", "CSV generato: accessi_negati.csv")


            case 2:
                messagebox.showinfo("Risultato", "Hai scelto l'Opzione 2!\nEsecuzione azione 2...")
                subprocess.run(["bash", "Domanda2.sh"])
            case 3:
                messagebox.showinfo("Risultato", "Hai scelto l'Opzione 3!\nEsecuzione azione 3...")
                subprocess.run(["bash", "Domanda3.sh"])
            case 4:
                messagebox.showinfo("Risultato", "Hai scelto l'Opzione 4!\nEsecuzione azione 4...")
                subprocess.run(["bash", "script.sh"])
            case 5:
                messagebox.showinfo("Risultato", "Hai scelto l'Opzione 5!\nEsecuzione azione 5...")
                subprocess.run(["bash", "script.sh"])
            case 6:
                messagebox.showinfo("Risultato", "Hai scelto l'Opzione 6!\nEsecuzione azione 6...")
                subprocess.run(["bash", "script.sh"])
            case 7:
                messagebox.showinfo("Risultato", "Hai scelto l'Opzione 7!\nEsecuzione azione 7...")
                subprocess.run(["bash", "script.sh"])
            case 8:
                messagebox.showinfo("Risultato", "Hai scelto l'Opzione 8!\nEsecuzione azione 8...")
                subprocess.run(["bash", "script.sh"])
            case 9:
                messagebox.showinfo("Risultato", "Hai scelto l'Opzione 9!\nEsecuzione azione 9...")
                subprocess.run(["bash", "script.sh"])

            case 10:
                messagebox.showinfo("Risultato", "Hai scelto l'Opzione 10!\nEsecuzione azione 10...")
                subprocess.run(["bash", "script.sh"])
            case _:
                messagebox.showerror("Errore", "Opzione non valida!")

if __name__ == "__main__":
    root = tk.Tk()
    app = MenuGUI(root)
    root.mainloop()
