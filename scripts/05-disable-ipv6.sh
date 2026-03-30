#!/bin/bash
# =============================================================================
# 05 - Wyłączenie IPv6
# =============================================================================
# Ten skrypt:
# 1. Wyłącza IPv6 przez sysctl (kernel)
# 2. Ustawia persistence po restarcie
#
# Dlaczego? Jeśli nie używasz IPv6, to dodatkowa powierzchnia ataku.
# Większość VPS-ów nie potrzebuje IPv6.
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
echo "  Krok 5: Wyłączenie IPv6"
echo "============================================"
echo ""

# Sprawdź aktualny stan
IPV6_STATUS=$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)

if [[ "$IPV6_STATUS" == "1" ]]; then
    info "IPv6 już wyłączone."
    exit 0
fi

SYSCTL_CONF="/etc/sysctl.d/99-disable-ipv6.conf"

if [[ -f "$SYSCTL_CONF" ]]; then
    info "Konfiguracja już istnieje: $SYSCTL_CONF"
else
    cat > "$SYSCTL_CONF" << EOF
# Wyłączenie IPv6 — zmniejsza powierzchnię ataku
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    info "Konfiguracja zapisana: $SYSCTL_CONF"
fi

# Zastosuj natychmiast
sysctl -p "$SYSCTL_CONF" 2>/dev/null
info "IPv6 wyłączone."

# Weryfikacja
IPV6_NOW=$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)
if [[ "$IPV6_NOW" == "1" ]]; then
    info "Weryfikacja OK — IPv6 wyłączone."
else
    error "Coś poszło nie tak. Sprawdź ręcznie: cat /proc/sys/net/ipv6/conf/all/disable_ipv6"
fi

echo ""
info "IPv6 wyłączone. Zmiana przetrwa restart serwera."
echo ""
