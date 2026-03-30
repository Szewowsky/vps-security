#!/bin/bash
# =============================================================================
# 03 - Konfiguracja firewalla (UFW)
# =============================================================================
# Ten skrypt:
# 1. Instaluje UFW (jeśli brak)
# 2. Ustawia domyślne reguły (blokuj wejście, pozwól wyjście)
# 3. Otwiera potrzebne porty (SSH, HTTP, HTTPS)
# 4. Włącza firewall
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
echo "  Krok 3: Konfiguracja firewalla (UFW)"
echo "============================================"
echo ""

# Instaluj UFW jeśli brak
if ! command -v ufw &>/dev/null; then
    apt-get update -qq
    apt-get install -y -qq ufw
    info "UFW zainstalowany."
else
    info "UFW już zainstalowany."
fi

# Sprawdź aktualny port SSH
SSH_PORT=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
SSH_PORT=${SSH_PORT:-22}

echo "Wykryty port SSH: $SSH_PORT"
echo ""

# Domyślne reguły
ufw default deny incoming 2>/dev/null
ufw default allow outgoing 2>/dev/null
info "Domyślne reguły: blokuj wejście, pozwól wyjście."

# Port SSH (KRYTYCZNE — bez tego stracisz dostęp!)
ufw allow "$SSH_PORT/tcp" 2>/dev/null
info "Port $SSH_PORT (SSH) otwarty."

# HTTP i HTTPS (dla stron/aplikacji webowych)
read -rp "Otworzyć port 80 (HTTP) i 443 (HTTPS)? (tak/nie) [tak]: " OPEN_WEB
OPEN_WEB=${OPEN_WEB:-tak}

if [[ "$OPEN_WEB" == "tak" ]]; then
    ufw allow 80/tcp 2>/dev/null
    ufw allow 443/tcp 2>/dev/null
    info "Porty 80 (HTTP) i 443 (HTTPS) otwarte."
fi

# Dodatkowe porty
echo ""
read -rp "Dodatkowe porty do otwarcia (oddzielone spacją, Enter = pomiń): " EXTRA_PORTS

if [[ -n "$EXTRA_PORTS" ]]; then
    for PORT in $EXTRA_PORTS; do
        ufw allow "$PORT/tcp" 2>/dev/null
        info "Port $PORT otwarty."
    done
fi

# Zamknij domyślny port 22 jeśli SSH jest na innym
if [[ "$SSH_PORT" != "22" ]]; then
    ufw deny 22/tcp 2>/dev/null
    info "Port 22 zamknięty (SSH na porcie $SSH_PORT)."
fi

# Włącz UFW
echo ""
if ufw status | grep -q "Status: active"; then
    info "UFW już aktywny. Przeładowuję reguły."
    ufw reload
else
    warn "Włączam firewall. Upewnij się że port SSH ($SSH_PORT) jest otwarty!"
    echo "y" | ufw enable
    info "UFW włączony."
fi

# Pokaż status
echo ""
echo "Aktualne reguły:"
echo "---"
ufw status numbered
echo ""

info "Firewall skonfigurowany."
echo ""
