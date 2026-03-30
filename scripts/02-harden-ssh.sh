#!/bin/bash
# =============================================================================
# 02 - Hardening SSH
# =============================================================================
# Ten skrypt:
# 1. Zmienia domyślny port SSH (z 22 na wybrany)
# 2. Wyłącza logowanie hasłem (wymusza klucze SSH)
# 3. Wyłącza puste hasła
# 4. Ustawia timeout nieaktywnej sesji
# 5. Ogranicza liczbę prób logowania
#
# WAŻNE: Upewnij się że masz klucz SSH ZANIM wyłączysz logowanie hasłem!
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
echo "  Krok 2: Hardening SSH"
echo "============================================"
echo ""

SSH_CONFIG="/etc/ssh/sshd_config"
CURRENT_PORT=$(grep -E "^Port " "$SSH_CONFIG" 2>/dev/null | awk '{print $2}')
CURRENT_PORT=${CURRENT_PORT:-22}

echo "Aktualny port SSH: $CURRENT_PORT"
echo ""

# --- Port SSH ---
read -rp "Nowy port SSH (Enter = zostaw $CURRENT_PORT): " NEW_PORT
NEW_PORT=${NEW_PORT:-$CURRENT_PORT}

if [[ "$NEW_PORT" -lt 1024 || "$NEW_PORT" -gt 65535 ]]; then
    if [[ "$NEW_PORT" -ne 22 ]]; then
        error "Port musi być w zakresie 1024-65535 (lub 22)."
        exit 1
    fi
fi

# Backup konfiguracji
cp "$SSH_CONFIG" "${SSH_CONFIG}.bak.$(date +%Y%m%d)" 2>/dev/null || true

# Funkcja do ustawienia parametru SSH
set_ssh_param() {
    local param="$1"
    local value="$2"

    if grep -q "^${param}" "$SSH_CONFIG"; then
        sed -i "s/^${param}.*/${param} ${value}/" "$SSH_CONFIG"
    elif grep -q "^#${param}" "$SSH_CONFIG"; then
        sed -i "s/^#${param}.*/${param} ${value}/" "$SSH_CONFIG"
    else
        echo "${param} ${value}" >> "$SSH_CONFIG"
    fi
}

# Sprawdź czy cloud-init nadpisuje config
CLOUD_INIT_SSH="/etc/ssh/sshd_config.d/50-cloud-init.conf"
if [[ -f "$CLOUD_INIT_SSH" ]]; then
    warn "Znaleziono config cloud-init: $CLOUD_INIT_SSH"
    warn "Ustawienia z tego pliku mogą nadpisywać sshd_config!"

    # Ustaw też w cloud-init
    if grep -q "^PasswordAuthentication" "$CLOUD_INIT_SSH"; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$CLOUD_INIT_SSH"
    fi
fi

# Zmiana portu
if [[ "$NEW_PORT" != "$CURRENT_PORT" ]]; then
    set_ssh_param "Port" "$NEW_PORT"
    info "Port SSH zmieniony: $CURRENT_PORT → $NEW_PORT"
else
    info "Port SSH bez zmian: $CURRENT_PORT"
fi

# Wyłącz logowanie hasłem
set_ssh_param "PasswordAuthentication" "no"
info "Logowanie hasłem wyłączone (wymaga klucza SSH)."

# Wyłącz puste hasła
set_ssh_param "PermitEmptyPasswords" "no"
info "Puste hasła wyłączone."

# Timeout nieaktywnej sesji (5 minut)
set_ssh_param "ClientAliveInterval" "300"
set_ssh_param "ClientAliveCountMax" "2"
info "Timeout nieaktywnej sesji: 10 min (300s × 2)."

# Maksymalna liczba prób logowania
set_ssh_param "MaxAuthTries" "3"
info "Maks. próby logowania: 3."

# Wyłącz X11 forwarding (niepotrzebne na serwerze)
set_ssh_param "X11Forwarding" "no"
info "X11 forwarding wyłączony."

# Sprawdź składnię konfiguracji
echo ""
if sshd -t 2>/dev/null; then
    info "Konfiguracja SSH poprawna."

    # Restart SSH
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
    info "SSH zrestartowane."
else
    error "Błąd w konfiguracji SSH! Przywracam backup."
    cp "${SSH_CONFIG}.bak.$(date +%Y%m%d)" "$SSH_CONFIG"
    error "Sprawdź ręcznie: sshd -t"
    exit 1
fi

# Przypomnienie o firewall
if [[ "$NEW_PORT" != "$CURRENT_PORT" ]]; then
    echo ""
    warn "WAŻNE: Dodaj nowy port do firewalla!"
    echo "  sudo ufw allow $NEW_PORT/tcp"
    echo "  sudo ufw deny $CURRENT_PORT/tcp  # (zamknij stary port)"
    echo ""
    warn "NIE zamykaj tego terminala dopóki nie przetestujesz nowego portu!"
fi

echo ""
info "SSH hardening zakończony."
echo ""
