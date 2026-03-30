# VPS Security Hardening 🛡️

Zabezpiecz swój serwer VPS w 8 krokach. Gotowe skrypty + interaktywny przewodnik z Claude Code.

## Dla kogo?

Masz VPS z Ubuntu (22.04 / 24.04) i chcesz go zabezpieczyć — ale nie wiesz od czego zacząć? Ten projekt przeprowadzi Cię krok po kroku.

## Co dostajesz?

- **8 gotowych skryptów** — każdy krok osobno, z wyjaśnieniem po polsku
- **Skrypt audytu** — sprawdza co masz, co brakuje
- **Interaktywny przewodnik** — Claude Code prowadzi Cię przez cały proces

## Quick Start

### Opcja A: Z Claude Code (zalecane)

```bash
git clone https://github.com/Szewowsky/vps-security.git
cd vps-security
claude
# wpisz: /hardening
```

Claude Code poprowadzi Cię interaktywnie przez wszystkie 8 kroków.

### Opcja B: Ręcznie

```bash
git clone https://github.com/Szewowsky/vps-security.git
# Skopiuj skrypty na serwer:
scp -P TWOJ_PORT scripts/*.sh user@IP:/tmp/

# Na serwerze:
sudo bash /tmp/audit.sh          # sprawdź co masz
sudo bash /tmp/01-create-user.sh # zacznij od kroku 1
# ... kolejne skrypty po kolei
```

## 8 kroków

| # | Co | Skrypt |
|---|-----|--------|
| 1 | Stworzenie użytkownika (wyłączenie root) | `01-create-user.sh` |
| 2 | Hardening SSH (port, klucze, limity) | `02-harden-ssh.sh` |
| 3 | Firewall (UFW) | `03-setup-firewall.sh` |
| 4 | Fail2ban (ochrona przed brute-force) | `04-setup-fail2ban.sh` |
| 5 | Wyłączenie IPv6 | `05-disable-ipv6.sh` |
| 6 | Antywirus (ClamAV) | `06-setup-clamav.sh` |
| 7 | Monitoring logów | `07-log-monitoring.sh` |
| 8 | Automatyczne aktualizacje | `08-auto-updates.sh` |

## Audyt

Nie wiesz co masz skonfigurowane? Uruchom audyt:

```bash
sudo bash scripts/audit.sh
```

Dostaniesz raport: co jest OK, co wymaga uwagi.

## Ważne

- **Nie zamykaj sesji SSH** dopóki nie przetestujesz nowego logowania
- Uruchamiaj skrypty **po kolei** (1 → 2 → 3 → ...)
- Skrypty są **idempotentne** — bezpieczne do wielokrotnego uruchomienia
- Testuj na świeżym VPS zanim użyjesz na produkcji

## Źródła

Bazowane na: [Hostinger VPS Security Guide](https://www.hostinger.com/tutorials/vps-security)

---

Materiał towarzyszący do filmu na YouTube. Kanał: [Robert Szewczyk](https://youtube.com/@robert_szewczyk)
