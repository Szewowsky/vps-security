# CLAUDE.md — VPS Security Hardening

Interaktywny przewodnik zabezpieczenia serwera VPS (Ubuntu 22/24).
Przeznaczony do użycia z Claude Code — otwórz projekt i wpisz `/hardening`.

## Wymagania

- VPS z Ubuntu 22.04 lub 24.04
- Dostęp SSH (root lub sudo)
- Claude Code zainstalowany lokalnie

## Quick Start

```bash
git clone https://github.com/Szewowsky/vps-security.git
cd vps-security
claude   # uruchom Claude Code
# wpisz: /hardening
```

## Slash Commands

| Komenda | Cel |
|---------|-----|
| `/hardening` | Interaktywny wizard — prowadzi przez 8 kroków zabezpieczenia |
| `/audit` | Sprawdza obecny stan bezpieczeństwa serwera |

## 8 kroków hardening

Każdy krok ma osobny skrypt w `scripts/`. Skrypty są idempotentne (bezpieczne do wielokrotnego uruchomienia).

### 1. Stworzenie użytkownika z sudo + wyłączenie root
**Skrypt:** `scripts/01-create-user.sh`
**Dlaczego:** Root ma nieograniczony dostęp. Jedno złe polecenie = awaria. Osobny user z sudo wymusza świadome `sudo` przed niebezpiecznymi komendami.
**Weryfikacja:** `ssh -p PORT user@IP` działa, `ssh -p PORT root@IP` nie działa.

### 2. Hardening SSH
**Skrypt:** `scripts/02-harden-ssh.sh`
**Dlaczego:** Domyślny port 22 jest skanowany przez boty non-stop. Klucze SSH są bezpieczniejsze niż hasła.
**Co robi:** zmiana portu, wyłączenie hasła, timeout, limit prób.
**Weryfikacja:** `sshd -t` (test konfiguracji), logowanie kluczem działa.

### 3. Firewall (UFW)
**Skrypt:** `scripts/03-setup-firewall.sh`
**Dlaczego:** Bez firewalla wszystkie porty są otwarte. UFW blokuje domyślnie wszystko oprócz tego co jawnie zezwolisz.
**Weryfikacja:** `ufw status` — powinien pokazywać tylko SSH, HTTP, HTTPS.

### 4. Fail2ban
**Skrypt:** `scripts/04-setup-fail2ban.sh`
**Dlaczego:** Banuje IP po wielokrotnych nieudanych próbach logowania. Ochrona przed brute-force.
**Weryfikacja:** `fail2ban-client status sshd`

### 5. Wyłączenie IPv6
**Skrypt:** `scripts/05-disable-ipv6.sh`
**Dlaczego:** Jeśli nie używasz IPv6, to niepotrzebna powierzchnia ataku.
**Weryfikacja:** `cat /proc/sys/net/ipv6/conf/all/disable_ipv6` → `1`

### 6. ClamAV (antywirus)
**Skrypt:** `scripts/06-setup-clamav.sh`
**Dlaczego:** Skanuje pliki pod kątem malware. Cotygodniowy automatyczny skan.
**Uwaga:** Wymaga ~2GB RAM.
**Weryfikacja:** `clamscan --version`, `systemctl status clamav-freshclam`

### 7. Monitoring logów
**Skrypt:** `scripts/07-log-monitoring.sh`
**Dlaczego:** Bez logów nie wiesz kto próbował się włamać. Logwatch generuje codzienny raport.
**Weryfikacja:** `cat /var/log/logwatch/daily-report.log`

### 8. Automatyczne aktualizacje
**Skrypt:** `scripts/08-auto-updates.sh`
**Dlaczego:** Security patches Ubuntu instalują się automatycznie. Nie musisz pamiętać o `apt upgrade`.
**Weryfikacja:** `unattended-upgrades --dry-run`

## Audyt

**Skrypt:** `scripts/audit.sh`
Sprawdza wszystkie 8 punktów i wyświetla raport PASS/FAIL/WARN.

```bash
# Na serwerze:
sudo bash audit.sh
```

## Troubleshooting

### Zablokowałem się z SSH!
1. Wejdź przez **panel Hostinger** (przeglądarkowy terminal)
2. Napraw konfigurację: `nano /etc/ssh/sshd_config`
3. Restart: `systemctl restart ssh`

### Fail2ban zbanował moje IP
```bash
# Sprawdź zbanowane IP:
fail2ban-client status sshd

# Odbanuj konkretne IP:
fail2ban-client set sshd unbanip TWOJE_IP
```

### ClamAV zjada za dużo RAM
```bash
# Wyłącz daemon, skanuj ręcznie:
systemctl stop clamav-daemon
clamscan -r /home   # skan na żądanie
```

## WAŻNE zasady

1. **NIGDY nie zamykaj sesji SSH** dopóki nie przetestujesz nowego logowania w osobnym terminalu
2. **Backup przed zmianami:** `cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak`
3. **Panel Hostinger** to Twoja siatka bezpieczeństwa — zawsze możesz wejść przez przeglądarkę
4. Uruchamiaj skrypty **po kolei** (1→2→3→...) — kolejność ma znaczenie
