#!/bin/bash
# =============================================================================
# 01 - Stworzenie użytkownika z sudo + wyłączenie logowania jako root
# =============================================================================
# Ten skrypt:
# 1. Tworzy nowego użytkownika z hasłem
# 2. Dodaje go do grupy sudo
# 3. Kopiuje klucze SSH z roota
# 4. Wyłącza logowanie jako root przez SSH
#
# WAŻNE: NIE zamykaj obecnej sesji SSH dopóki nie przetestujesz logowania
#        nowym użytkownikiem w OSOBNYM terminalu!
# =============================================================================

set -euo pipefail

# Kolory
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

# Sprawdź czy root
if [[ $EUID -ne 0 ]]; then
    error "Ten skrypt wymaga uprawnień root. Uruchom: sudo bash $0"
    exit 1
fi

echo "============================================"
echo "  Krok 1: Tworzenie użytkownika z sudo"
echo "============================================"
echo ""

# Zapytaj o nazwę użytkownika
read -rp "Podaj nazwę nowego użytkownika: " USERNAME

if [[ -z "$USERNAME" ]]; then
    error "Nazwa użytkownika nie może być pusta."
    exit 1
fi

# Sprawdź czy użytkownik już istnieje
if id "$USERNAME" &>/dev/null; then
    warn "Użytkownik '$USERNAME' już istnieje."

    # Sprawdź czy ma sudo
    if groups "$USERNAME" | grep -q sudo; then
        info "Użytkownik '$USERNAME' jest już w grupie sudo."
    else
        usermod -aG sudo "$USERNAME"
        info "Dodano '$USERNAME' do grupy sudo."
    fi
else
    # Stwórz użytkownika
    adduser --gecos "" "$USERNAME"
    usermod -aG sudo "$USERNAME"
    info "Stworzono użytkownika '$USERNAME' z uprawnieniami sudo."
fi

# Kopiuj klucze SSH z roota
if [[ -f /root/.ssh/authorized_keys ]]; then
    USER_HOME=$(eval echo "~$USERNAME")
    mkdir -p "$USER_HOME/.ssh"
    cp /root/.ssh/authorized_keys "$USER_HOME/.ssh/authorized_keys"
    chown -R "$USERNAME:$USERNAME" "$USER_HOME/.ssh"
    chmod 700 "$USER_HOME/.ssh"
    chmod 600 "$USER_HOME/.ssh/authorized_keys"
    info "Skopiowano klucze SSH z roota do '$USERNAME'."
else
    warn "Brak /root/.ssh/authorized_keys — musisz ręcznie dodać klucz SSH."
fi

echo ""
echo "============================================"
echo "  STOP! Przetestuj logowanie!"
echo "============================================"
echo ""
echo "Otwórz NOWY terminal i sprawdź:"
echo ""

# Znajdź aktualny port SSH
SSH_PORT=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
SSH_PORT=${SSH_PORT:-22}

echo "  ssh -p $SSH_PORT $USERNAME@$(hostname -I | awk '{print $1}')"
echo ""
echo "Jeśli działa, wróć tutaj i potwierdź."
echo ""

read -rp "Czy logowanie nowym użytkownikiem działa? (tak/nie): " CONFIRM

if [[ "$CONFIRM" != "tak" ]]; then
    warn "Przerywam. Nie wyłączam logowania root."
    warn "Napraw problem z logowaniem i uruchom skrypt ponownie."
    exit 1
fi

# Wyłącz logowanie root przez SSH
SSH_CONFIG="/etc/ssh/sshd_config"

if grep -q "^PermitRootLogin no" "$SSH_CONFIG"; then
    info "Logowanie root już wyłączone."
else
    # Backup
    cp "$SSH_CONFIG" "${SSH_CONFIG}.bak.$(date +%Y%m%d)"

    if grep -q "^PermitRootLogin" "$SSH_CONFIG"; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' "$SSH_CONFIG"
    else
        echo "PermitRootLogin no" >> "$SSH_CONFIG"
    fi

    # Restart SSH
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
    info "Logowanie root przez SSH wyłączone."
fi

echo ""
info "Gotowe! Od teraz loguj się jako '$USERNAME' i używaj 'sudo' dla komend admina."
echo ""
