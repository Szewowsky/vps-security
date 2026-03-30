#!/bin/bash
# =============================================================================
# Audyt bezpieczeństwa VPS
# =============================================================================
# Sprawdza co jest skonfigurowane, a co wymaga uwagi.
# Uruchom na serwerze: sudo bash audit.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "  ${GREEN}✅ PASS${NC}  $1"; ((PASS++)); }
fail() { echo -e "  ${RED}❌ FAIL${NC}  $1"; ((FAIL++)); }
warn() { echo -e "  ${YELLOW}⚠️  WARN${NC}  $1"; ((WARN++)); }
header() { echo -e "\n${BLUE}━━━ $1 ━━━${NC}"; }

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║       AUDYT BEZPIECZEŃSTWA VPS           ║"
echo "║       $(date +%Y-%m-%d\ %H:%M)                    ║"
echo "╚══════════════════════════════════════════╝"

# --- 1. Użytkownik ---
header "1. Użytkownik (non-root)"

if [[ $EUID -eq 0 ]]; then
    # Sprawdź czy istnieje jakiś user z sudo (poza root)
    SUDO_USERS=$(grep -E '^sudo:' /etc/group | cut -d: -f4)
    if [[ -n "$SUDO_USERS" ]]; then
        pass "Użytkownik z sudo istnieje: $SUDO_USERS"
    else
        fail "Brak użytkownika z sudo — logujesz się jako root!"
    fi
fi

# Sprawdź PermitRootLogin
ROOT_LOGIN=$(grep -E "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
if [[ "$ROOT_LOGIN" == "no" ]]; then
    pass "Logowanie root przez SSH wyłączone"
else
    fail "Logowanie root przez SSH włączone (PermitRootLogin: ${ROOT_LOGIN:-not set})"
fi

# --- 2. SSH ---
header "2. SSH Hardening"

SSH_PORT=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
SSH_PORT=${SSH_PORT:-22}

if [[ "$SSH_PORT" != "22" ]]; then
    pass "Port SSH zmieniony: $SSH_PORT"
else
    fail "Port SSH domyślny: 22"
fi

PASS_AUTH=$(grep -E "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
# Sprawdź też cloud-init
PASS_AUTH_CLOUD=$(grep -E "^PasswordAuthentication" /etc/ssh/sshd_config.d/50-cloud-init.conf 2>/dev/null | awk '{print $2}')
EFFECTIVE_PASS=${PASS_AUTH_CLOUD:-$PASS_AUTH}

if [[ "$EFFECTIVE_PASS" == "no" ]]; then
    pass "Logowanie hasłem wyłączone"
else
    fail "Logowanie hasłem włączone"
fi

if [[ -f /root/.ssh/authorized_keys ]] && [[ -s /root/.ssh/authorized_keys ]]; then
    KEY_COUNT=$(wc -l < /root/.ssh/authorized_keys)
    pass "Klucze SSH skonfigurowane ($KEY_COUNT kluczy)"
else
    fail "Brak kluczy SSH"
fi

MAX_AUTH=$(grep -E "^MaxAuthTries" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
if [[ -n "$MAX_AUTH" && "$MAX_AUTH" -le 5 ]]; then
    pass "MaxAuthTries: $MAX_AUTH"
else
    warn "MaxAuthTries nie ustawione (domyślnie: 6)"
fi

# --- 3. Firewall ---
header "3. Firewall (UFW)"

if command -v ufw &>/dev/null; then
    UFW_STATUS=$(ufw status 2>/dev/null | head -1)
    if echo "$UFW_STATUS" | grep -q "active"; then
        pass "UFW aktywny"
        OPEN_PORTS=$(ufw status | grep "ALLOW" | awk '{print $1}' | sort -u | tr '\n' ', ')
        echo -e "       Otwarte porty: ${OPEN_PORTS%,}"
    else
        fail "UFW zainstalowany ale nieaktywny"
    fi
else
    fail "UFW nie zainstalowany"
fi

# --- 4. Fail2ban ---
header "4. Fail2ban"

if command -v fail2ban-client &>/dev/null; then
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        pass "Fail2ban aktywny"

        if fail2ban-client status sshd &>/dev/null; then
            BANNED=$(fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $NF}')
            TOTAL=$(fail2ban-client status sshd 2>/dev/null | grep "Total banned" | awk '{print $NF}')
            echo "       Aktualnie zbanowane: $BANNED | Łącznie: $TOTAL"
        else
            warn "Jail sshd nieaktywny"
        fi
    else
        fail "Fail2ban zainstalowany ale nieaktywny"
    fi
else
    fail "Fail2ban nie zainstalowany"
fi

# --- 5. IPv6 ---
header "5. IPv6"

IPV6_DISABLED=$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)
if [[ "$IPV6_DISABLED" == "1" ]]; then
    pass "IPv6 wyłączone"
else
    warn "IPv6 włączone (jeśli nie używasz — wyłącz)"
fi

# --- 6. ClamAV ---
header "6. Antywirus (ClamAV)"

if command -v clamscan &>/dev/null; then
    pass "ClamAV zainstalowany"

    if systemctl is-active --quiet clamav-freshclam 2>/dev/null; then
        pass "Automatyczna aktualizacja baz aktywna"
    else
        warn "clamav-freshclam nieaktywny — bazy mogą być nieaktualne"
    fi
else
    warn "ClamAV nie zainstalowany"
fi

# --- 7. Log monitoring ---
header "7. Monitoring logów"

if command -v logwatch &>/dev/null; then
    pass "Logwatch zainstalowany"
else
    warn "Logwatch nie zainstalowany"
fi

if [[ -f /etc/cron.daily/security-report ]]; then
    pass "Codzienny raport bezpieczeństwa skonfigurowany"
else
    warn "Brak codziennego raportu bezpieczeństwa"
fi

# --- 8. Auto-updates ---
header "8. Automatyczne aktualizacje"

if dpkg -l 2>/dev/null | grep -q unattended-upgrades; then
    pass "unattended-upgrades zainstalowany"

    if [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]]; then
        pass "Auto-upgrades skonfigurowane"
    else
        warn "Brak konfiguracji auto-upgrades"
    fi
else
    fail "unattended-upgrades nie zainstalowany"
fi

# --- Podsumowanie ---
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║              PODSUMOWANIE                ║"
echo "╠══════════════════════════════════════════╣"
echo -e "║  ${GREEN}PASS: $PASS${NC}  ${RED}FAIL: $FAIL${NC}  ${YELLOW}WARN: $WARN${NC}          ║"
echo "╚══════════════════════════════════════════╝"

if [[ $FAIL -eq 0 ]]; then
    echo -e "\n${GREEN}Serwer wygląda dobrze! 🛡️${NC}\n"
elif [[ $FAIL -le 2 ]]; then
    echo -e "\n${YELLOW}Kilka rzeczy do poprawienia.${NC}\n"
else
    echo -e "\n${RED}Serwer wymaga uwagi — uruchom skrypty hardening.${NC}\n"
fi
