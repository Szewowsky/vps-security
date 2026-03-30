#!/bin/bash
# =============================================================================
# 08 - Automatyczne aktualizacje bezpieczeństwa
# =============================================================================
# Ten skrypt:
# 1. Instaluje unattended-upgrades
# 2. Konfiguruje automatyczne security patches
# 3. Włącza automatyczny restart (opcjonalnie)
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
echo "  Krok 8: Automatyczne aktualizacje"
echo "============================================"
echo ""

# Instaluj
if dpkg -l | grep -q unattended-upgrades; then
    info "unattended-upgrades już zainstalowany."
else
    apt-get update -qq
    apt-get install -y -qq unattended-upgrades apt-listchanges
    info "unattended-upgrades zainstalowany."
fi

# Konfiguracja auto-upgrades
AUTO_CONF="/etc/apt/apt.conf.d/20auto-upgrades"

if [[ -f "$AUTO_CONF" ]]; then
    info "Konfiguracja auto-upgrades już istnieje."
else
    cat > "$AUTO_CONF" << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
    info "Auto-upgrades skonfigurowane (codziennie)."
fi

# Opcjonalny auto-restart
echo ""
read -rp "Włączyć automatyczny restart po aktualizacjach wymagających restartu? (tak/nie) [nie]: " AUTO_REBOOT
AUTO_REBOOT=${AUTO_REBOOT:-nie}

UNATTENDED_CONF="/etc/apt/apt.conf.d/50unattended-upgrades"

if [[ "$AUTO_REBOOT" == "tak" ]]; then
    if [[ -f "$UNATTENDED_CONF" ]]; then
        # Włącz auto-reboot o 4:00 rano
        sed -i 's|//Unattended-Upgrade::Automatic-Reboot "false";|Unattended-Upgrade::Automatic-Reboot "true";|' "$UNATTENDED_CONF" 2>/dev/null
        sed -i 's|//Unattended-Upgrade::Automatic-Reboot-Time "02:00";|Unattended-Upgrade::Automatic-Reboot-Time "04:00";|' "$UNATTENDED_CONF" 2>/dev/null
        info "Auto-restart włączony (04:00 jeśli wymagany)."
    fi
else
    info "Auto-restart wyłączony — będziesz musiał restartować ręcznie."
fi

# Sprawdź status
echo ""
echo "Test konfiguracji:"
unattended-upgrades --dry-run 2>&1 | tail -5 || warn "Test nie powiódł się — sprawdź logi."

echo ""
info "Automatyczne aktualizacje skonfigurowane."
echo ""
echo "Przydatne komendy:"
echo "  Test:    unattended-upgrades --dry-run"
echo "  Logi:    cat /var/log/unattended-upgrades/unattended-upgrades.log"
echo "  Status:  systemctl status unattended-upgrades"
echo ""
