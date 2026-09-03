# Home Coaching — collaudo finale

Produzione: https://littlepaul24-code.github.io/Home-Coaching/

### Pagamenti
Per il collaudo usare Stripe in modalità Test, mai dati reali in Live. La carta di test 4242 4242 4242 4242 esegue con successo un pagamento; usare una scadenza futura e un CVC di 3 cifre. https://docs.stripe.com/testing

Il backend remoto usa `STRIPE_SECRET_KEY`: durante il test deve essere una chiave `sk_test_...`; per la produzione deve essere la chiave `sk_live_...`. Non includere mai la chiave nel sito o nel repository.

### Percorso da verificare
Questionario → creazione account → accesso cliente → checkout → successo → area cliente.
Area cliente: massimo 3 giorni/settimana, workout, completamento, check-in e timer.
Area coach: clienti, settimane, editor, libreria esercizi, pubblicazione, duplicazione settimana e risposte ai check-in.

PayPal non viene attivato finché non è disponibile un conto PayPal Business separato. Mantieni il PayPal personale per i pagamenti personali.

### Prezzi
€59/mese · €169/3 mesi · €329/6 mesi · €629/12 mesi
