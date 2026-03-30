#!/bin/bash
# =============================================================================
# 04 - Konfiguracja Fail2ban
# =============================================================================
# Ten skrypt:
# 1. Instaluje Fail2ban
# 2. Konfiguruje jail dla SSH (ban po 3 próbach na 24h)
# 3. Uruchamia i włącza autostart
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
    error "Ten skrypt wymaga uprawnień root. Uruchom: sudo bash $0"
    exit 1
fi

echo "============================================"
echo "  Krok 4: Konfiguracja Fail2ban"
echo "============================================"
echo ""

# Instaluj jeśli brak
if ! command -v fail2ban-client &>/dev/null; then
    apt-get update -qq
    apt-get install -y -qq fail2ban
    info "Fail2ban zainstalowany."
else
    info "Fail2ban już zainstalowany."
fi

# Sprawdź port SSH
SSH_PORT=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
SSH_PORT=${SSH_PORT:-22}

# Konfiguracja jail
JAIL_LOCAL="/etc/fail2ban/jail.local"

if [[ -f "$JAIL_LOCAL" ]]; then
    warn "Plik $JAIL_LOCAL już istnieje."
    read -rp "Nadpisać konfigurację? (tak/nie) [nie]: " OVERWRITE
    OVERWRITE=${OVERWRITE:-nie}

    if [[ "$OVERWRITE" != "tak" ]]; then
        info "Zostawiam istniejącą konfigurację."
        echo ""
        echo "Aktualny status:"
        fail2ban-client status sshd 2>/dev/null || warn "Jail sshd nieaktywny."
        exit 0
    fi

    cp "$JAIL_LOCAL" "${JAIL_LOCAL}.bak.$(date +%Y%m%d)"
fi

# Zapytaj o parametry
read -rp "Maks. nieudanych prób przed banem [3]: " MAX_RETRY
MAX_RETRY=${MAX_RETRY:-3}

read -rp "Czas bana w godzinach [24]: " BAN_HOURS
BAN_HOURS=${BAN_HOURS:-24}

BAN_TIME=$((BAN_HOURS * 3600))

cat > "$JAIL_LOCAL" << EOF
[DEFAULT]
# Ban na ${BAN_HOURS}h
bantime = ${BAN_TIME}

# Okno czasowe na próby: 1h
findtime = 3600

# Maks. nieudanych prób
maxretry = ${MAX_RETRY}

# Akcja: ban IP przez UFW
banaction = ufw

[sshd]
enabled = true
port = ${SSH_PORT}
filter = sshd
logpath = /var/log/auth.log
EOF

info "Konfiguracja zapisana: ban po $MAX_RETRY próbach na ${BAN_HOURS}h."

# Restart fail2ban
systemctl enable fail2ban 2>/dev/null
systemctl restart fail2ban

# Sprawdź status
echo ""
if fail2ban-client status sshd &>/dev/null; then
    info "Fail2ban działa."
    echo ""
    fail2ban-client status sshd
else
    error "Problem z uruchomieniem jail sshd."
    echo "Sprawdź logi: journalctl -u fail2ban"
fi

echo ""
info "Fail2ban skonfigurowany."
echo ""
