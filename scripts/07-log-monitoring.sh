#!/bin/bash
# =============================================================================
# 07 - Monitoring logów
# =============================================================================
# Ten skrypt:
# 1. Instaluje logwatch (raporty mailowe/konsolowe)
# 2. Konfiguruje codzienny raport bezpieczeństwa
# 3. Pokazuje jak ręcznie sprawdzać logi
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
echo "  Krok 7: Monitoring logów"
echo "============================================"
echo ""

# Instaluj logwatch
if command -v logwatch &>/dev/null; then
    info "Logwatch już zainstalowany."
else
    apt-get update -qq
    apt-get install -y -qq logwatch
    info "Logwatch zainstalowany."
fi

# Konfiguracja logwatch
LOGWATCH_CONF="/etc/logwatch/conf/logwatch.conf"
mkdir -p /etc/logwatch/conf

if [[ -f "$LOGWATCH_CONF" ]]; then
    info "Konfiguracja logwatch już istnieje."
else
    cat > "$LOGWATCH_CONF" << EOF
# Codzienny raport bezpieczeństwa
Output = file
Filename = /var/log/logwatch/daily-report.log
Format = text
Range = yesterday
Detail = Med
Service = sshd
Service = pam_unix
Service = sudo
Service = fail2ban
EOF
    mkdir -p /var/log/logwatch
    info "Konfiguracja logwatch zapisana."
fi

# Codzienny cron
CRON_FILE="/etc/cron.daily/security-report"
if [[ -f "$CRON_FILE" ]]; then
    info "Codzienny raport już skonfigurowany."
else
    cat > "$CRON_FILE" << 'CRONEOF'
#!/bin/bash
# Codzienny raport bezpieczeństwa
REPORT="/var/log/logwatch/daily-report.log"
DATE=$(date +%Y-%m-%d)

echo "========================================" >> "$REPORT"
echo "  Raport bezpieczeństwa: $DATE" >> "$REPORT"
echo "========================================" >> "$REPORT"

# Logwatch
logwatch --range yesterday --detail Med --service sshd --service sudo --service fail2ban >> "$REPORT" 2>/dev/null

# Nieudane logowania SSH (ostatnie 24h)
echo "" >> "$REPORT"
echo "--- Nieudane logowania SSH ---" >> "$REPORT"
journalctl -u ssh --since "24 hours ago" 2>/dev/null | grep -i "failed\|invalid" >> "$REPORT" 2>/dev/null || echo "Brak" >> "$REPORT"

# Fail2ban bany
echo "" >> "$REPORT"
echo "--- Fail2ban bany ---" >> "$REPORT"
fail2ban-client status sshd 2>/dev/null >> "$REPORT" || echo "Fail2ban nieaktywny" >> "$REPORT"
CRONEOF
    chmod +x "$CRON_FILE"
    info "Codzienny raport bezpieczeństwa skonfigurowany."
fi

# Pierwszy raport
echo ""
echo "Generuję przykładowy raport..."
echo ""

echo "--- Ostatnie nieudane logowania SSH ---"
journalctl -u ssh --since "7 days ago" 2>/dev/null | grep -i "failed\|invalid" | tail -10 || echo "  Brak danych"

echo ""
echo "--- Fail2ban status ---"
fail2ban-client status sshd 2>/dev/null || echo "  Fail2ban nieaktywny"

echo ""
echo "--- Ostatnie logowania sudo ---"
journalctl _COMM=sudo --since "7 days ago" 2>/dev/null | tail -5 || echo "  Brak danych"

echo ""
info "Monitoring logów skonfigurowany."
echo ""
echo "Przydatne komendy:"
echo "  Raport:              cat /var/log/logwatch/daily-report.log"
echo "  Logi SSH:            journalctl -u ssh --since '24 hours ago'"
echo "  Kto się logował:     last -10"
echo "  Nieudane logowania:  lastb -10"
echo "  Fail2ban bany:       fail2ban-client status sshd"
echo ""
