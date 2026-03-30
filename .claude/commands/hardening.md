# /hardening — Interaktywny wizard zabezpieczenia VPS

Przeprowadź użytkownika krok po kroku przez zabezpieczenie serwera VPS.

## WAŻNE ZASADY

1. **NIE próbuj sam łączyć się przez SSH** — nie znasz hasła użytkownika. Zamiast tego mów użytkownikowi co wpisać.
2. Użytkownik wpisuje komendy z prefixem `!` (np. `! ssh root@IP`) — to uruchamia je w terminalu Claude Code.
3. Każdy krok = **jedna komenda na raz**. Nie dawaj 5 komend naraz.
4. **Czekaj na output** każdej komendy zanim przejdziesz dalej.
5. Tłumacz prostym językiem CO robi każda komenda i DLACZEGO.

## Workflow

### Krok 0: Połączenie z serwerem

Powiedz użytkownikowi:

"Najpierw musimy połączyć się z Twoim serwerem. Wpisz w terminalu:

`! ssh root@TWOJE_IP`

(Jeśli masz inny port niż 22, to: `! ssh -p PORT root@TWOJE_IP`)

Wpisz hasło gdy poprosi."

Poczekaj aż użytkownik się połączy i pokaże output.

### Krok 1: Pobierz skrypty na serwer

Gdy użytkownik jest już na serwerze (widać `root@...`), powiedz:

"Super, jesteś na serwerze! Teraz pobierzmy skrypty. Wpisz:

`! apt install git -y`

A potem:

`! git clone https://github.com/Szewowsky/vps-security.git /tmp/vps-security`"

### Krok 2: Audyt

"Sprawdźmy co już masz zabezpieczone:

`! bash /tmp/vps-security/scripts/audit.sh`"

Przeanalizuj output audytu. Powiedz użytkownikowi:
- Co jest już OK (zielone/PASS)
- Co trzeba zrobić (czerwone/FAIL)
- Które kroki pominiemy (bo już zrobione)

### Krok 3-10: Skrypty po kolei

Dla każdego brakującego kroku (FAIL w audycie):

1. Wyjaśnij **po co** ten krok (1-2 zdania, prosty język)
2. Powiedz: "Wpisz: `! bash /tmp/vps-security/scripts/XX-nazwa.sh`"
3. Skrypt jest interaktywny — pyta o dane. Pomóż użytkownikowi odpowiedzieć.
4. Po skrypcie — powiedz czy się udało i co dalej.

Kolejność skryptów:
- `01-create-user.sh` — stworzenie użytkownika (NAJWAŻNIEJSZE: przypomnij o testowaniu w nowym terminalu!)
- `02-harden-ssh.sh` — SSH hardening
- `03-setup-firewall.sh` — firewall
- `04-setup-fail2ban.sh` — ochrona przed brute-force
- `05-disable-ipv6.sh` — wyłączenie IPv6
- `06-setup-clamav.sh` — antywirus
- `07-log-monitoring.sh` — monitoring logów
- `08-auto-updates.sh` — automatyczne aktualizacje

### KRYTYCZNE MOMENTY (zwolnij, upewnij się):

**Po kroku 1 (create user):**
"STOP. Otwórz DRUGI terminal (nie zamykaj tego!) i sprawdź czy możesz się zalogować nowym użytkownikiem:
`ssh -p PORT nowy_user@IP`
Działa? Dopiero wtedy wróć tutaj i potwierdź."

**Po kroku 2 (SSH hardening) jeśli zmienił port:**
"STOP. Otwórz DRUGI terminal i sprawdź nowy port:
`ssh -p NOWY_PORT user@IP`
Działa? Nie zamykaj starego terminala!"

### Krok końcowy: Audyt ponownie

"Uruchommy audyt jeszcze raz żeby zobaczyć postęp:

`! bash /tmp/vps-security/scripts/audit.sh`"

Porównaj wyniki z pierwszym audytem. Pochwal użytkownika za każdy PASS.

## Ton

- Prosty język, zero żargonu bez wyjaśnienia
- Jedna komenda na raz
- "Wpisz: ..." zamiast "Uruchom polecenie..."
- Wyjaśniaj analogiami ("Firewall to jak zamek w drzwiach — wpuszcza tylko tych, których zaprosisz")
