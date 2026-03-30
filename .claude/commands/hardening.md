# /hardening — Interaktywny wizard zabezpieczenia VPS

Przeprowadź użytkownika przez 8 kroków zabezpieczenia serwera VPS.

## Instrukcje

1. Zapytaj o dane serwera:
   - IP serwera
   - Aktualny port SSH (domyślnie 22)
   - Nazwa nowego użytkownika (jeśli jeszcze nie ma)

2. Skopiuj skrypty na serwer:
   ```bash
   scp -P PORT scripts/*.sh user@IP:/tmp/
   ```

3. Uruchom audyt żeby sprawdzić co już jest:
   ```bash
   ssh -p PORT user@IP "sudo bash /tmp/audit.sh"
   ```

4. Na podstawie wyników audytu prowadź użytkownika przez brakujące kroki **po kolei**:
   - Krok 1: `sudo bash /tmp/01-create-user.sh`
   - Krok 2: `sudo bash /tmp/02-harden-ssh.sh`
   - Krok 3: `sudo bash /tmp/03-setup-firewall.sh`
   - Krok 4: `sudo bash /tmp/04-setup-fail2ban.sh`
   - Krok 5: `sudo bash /tmp/05-disable-ipv6.sh`
   - Krok 6: `sudo bash /tmp/06-setup-clamav.sh`
   - Krok 7: `sudo bash /tmp/07-log-monitoring.sh`
   - Krok 8: `sudo bash /tmp/08-auto-updates.sh`

5. Między krokami:
   - **ZAWSZE** przypomnij: "Nie zamykaj tego terminala!"
   - Po kroku 1: poczekaj aż user potwierdzi że nowe logowanie działa
   - Po kroku 2: poczekaj aż user potwierdzi że SSH działa na nowym porcie
   - Po kroku 3: upewnij się że port SSH jest na liście allowed

6. Na końcu uruchom audyt ponownie i pokaż postęp.

## Ważne

- Skrypty są interaktywne — pytają o dane. Nie podawaj wartości z góry.
- Jeśli krok jest już zrobiony (audyt = PASS), pomiń go.
- Jeśli coś pójdzie nie tak — panel Hostinger to plan B (przeglądarkowy terminal).
