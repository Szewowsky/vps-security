#!/bin/bash
# =============================================================================
# 06 - Instalacja ClamAV (antywirus)
# =============================================================================
# Ten skrypt:
# 1. Instaluje ClamAV i daemon
# 2. Aktualizuje bazy wirusów
# 3. Uruchamia skan katalogu /home i /root
# 4. Konfiguruje cotygodniowy automatyczny skan (cron)
#
# Uwaga: ClamAV potrzebuje ~2GB RAM. Na małych VPS-ach może być ciężko.
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
echo "  Krok 6: Instalacja ClamAV (antywirus)"
echo "============================================"
echo ""

# Sprawdź RAM
TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
if [[ "$TOTAL_RAM_MB" -lt 1500 ]]; then
    warn "Masz ${TOTAL_RAM_MB}MB RAM. ClamAV potrzebuje ~2GB."
    read -rp "Kontynuować mimo to? (tak/nie) [nie]: " CONTINUE
    CONTINUE=${CONTINUE:-nie}
    if [[ "$CONTINUE" != "tak" ]]; then
        echo "Przerwano."
        exit 0
    fi
fi

# Instaluj ClamAV
if command -v clamscan &>/dev/null; then
    info "ClamAV już zainstalowany."
else
    apt-get update -qq
    apt-get install -y -qq clamav clamav-daemon
    info "ClamAV zainstalowany."
fi

# Zatrzymaj daemon na czas aktualizacji baz
systemctl stop clamav-freshclam 2>/dev/null || true

# Aktualizuj bazy wirusów
echo ""
echo "Aktualizuję bazy wirusów (może potrwać kilka minut)..."
freshclam 2>/dev/null || warn "Aktualizacja baz mogła się nie udać — spróbuj później: sudo freshclam"

# Uruchom daemon
systemctl start clamav-freshclam 2>/dev/null
systemctl enable clamav-freshclam 2>/dev/null
info "ClamAV daemon uruchomiony (automatyczna aktualizacja baz)."

# Pierwszy skan
echo ""
read -rp "Uruchomić skan teraz? Może potrwać kilka minut. (tak/nie) [tak]: " RUN_SCAN
RUN_SCAN=${RUN_SCAN:-tak}

if [[ "$RUN_SCAN" == "tak" ]]; then
    echo "Skanuję /home i /root..."
    clamscan -r --infected --no-summary /home /root 2>/dev/null || true

    INFECTED=$(clamscan -r --infected /home /root 2>/dev/null | grep "Infected files:" | awk '{print $3}')

    if [[ "$INFECTED" == "0" || -z "$INFECTED" ]]; then
        info "Skan czysty — brak zagrożeń."
    else
        error "Znaleziono $INFECTED zainfekowanych plików!"
        echo "Uruchom pełny skan: clamscan -r --infected /home /root"
    fi
fi

# Cotygodniowy cron
CRON_FILE="/etc/cron.weekly/clamav-scan"
if [[ -f "$CRON_FILE" ]]; then
    info "Cotygodniowy skan już skonfigurowany."
else
    cat > "$CRON_FILE" << 'EOF'
#!/bin/bash
# Cotygodniowy skan ClamAV
LOG="/var/log/clamav/weekly-scan.log"
echo "=== Skan $(date) ===" >> "$LOG"
clamscan -r --infected /home /root /var/www 2>/dev/null >> "$LOG"
EOF
    chmod +x "$CRON_FILE"
    info "Cotygodniowy automatyczny skan skonfigurowany."
fi

echo ""
info "ClamAV gotowy."
echo "  Ręczny skan:    clamscan -r --infected /ścieżka"
echo "  Logi:           /var/log/clamav/"
echo ""
