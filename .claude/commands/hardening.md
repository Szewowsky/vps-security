# /hardening — Automatyczny wizard zabezpieczenia VPS

Zabezpiecz serwer VPS automatycznie. Użytkownik podaje IP, port, login i hasło — Claude robi resztę.

## Workflow

### Faza 0: Zbierz dane

Zapytaj użytkownika (AskUserQuestion) o:
- **IP serwera**
- **Port SSH** (domyślnie 22)
- **Login** (domyślnie root)
- **Hasło do serwera**

Zapisz te dane — będziesz ich używać w każdym kroku.

### Faza 1: Setup klucza SSH

Sprawdź czy klucz SSH już istnieje lokalnie:
```bash
ls ~/.ssh/id_ed25519.pub
```

Jeśli nie ma — wygeneruj:
```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
```

Dodaj klucz serwera do known_hosts (żeby nie pytał o fingerprint):
```bash
ssh-keyscan -p PORT IP >> ~/.ssh/known_hosts 2>/dev/null
```

Skopiuj klucz na serwer używając hasła:
```bash
sshpass -p 'HASLO' ssh-copy-id -p PORT -o StrictHostKeyChecking=no LOGIN@IP
```

Przetestuj połączenie BEZ hasła:
```bash
ssh -p PORT LOGIN@IP "echo 'SSH KEY OK'"
```

Jeśli test nie przejdzie — powiedz użytkownikowi co poszło nie tak. Nie idź dalej.

**Od tego momentu NIE używaj już hasła — tylko klucz SSH.**

### Faza 2: Przygotowanie serwera

Skopiuj skrypty na serwer:
```bash
scp -P PORT scripts/*.sh LOGIN@IP:/tmp/
```

Uruchom audyt:
```bash
ssh -p PORT LOGIN@IP "bash /tmp/audit.sh"
```

Przeanalizuj output. Powiedz użytkownikowi co jest OK, co brakuje. Wymień konkretne kroki do zrobienia.

### Faza 3: Hardening — krok po kroku

Dla każdego kroku który jest FAIL w audycie, uruchom skrypt zdalnie. Skrypty są interaktywne (pytają o dane), więc **NIE uruchamiaj ich przez `ssh "bash script.sh"`** — to nie zadziała z interaktywnymi promptami.

Zamiast tego wykonuj komendy ręcznie na serwerze, symulując to co skrypty robią:

#### Krok 1: Stworzenie użytkownika (jeśli FAIL)
```bash
# Zapytaj użytkownika o nazwę nowego usera
ssh -p PORT LOGIN@IP "adduser --disabled-password --gecos '' NOWY_USER"
ssh -p PORT LOGIN@IP "usermod -aG sudo NOWY_USER"
ssh -p PORT LOGIN@IP "mkdir -p /home/NOWY_USER/.ssh && cp /root/.ssh/authorized_keys /home/NOWY_USER/.ssh/authorized_keys && chown -R NOWY_USER:NOWY_USER /home/NOWY_USER/.ssh && chmod 700 /home/NOWY_USER/.ssh && chmod 600 /home/NOWY_USER/.ssh/authorized_keys"
ssh -p PORT LOGIN@IP "echo 'NOWY_USER ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/NOWY_USER && chmod 440 /etc/sudoers.d/NOWY_USER"
```

Przetestuj logowanie nowym userem:
```bash
ssh -p PORT NOWY_USER@IP "whoami && sudo whoami"
```

Jeśli OK — wyłącz root login:
```bash
ssh -p PORT NOWY_USER@IP "sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config"
ssh -p PORT NOWY_USER@IP "sudo systemctl restart ssh"
```

**Od tego momentu używaj NOWY_USER zamiast root.**

#### Krok 2: SSH hardening (jeśli FAIL)
Zapytaj użytkownika o nowy port SSH (np. 2222).
```bash
ssh -p PORT USER@IP "sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d)"
```

Ustaw parametry przez sed (każdy osobnym poleceniem):
```bash
ssh -p PORT USER@IP "sudo sed -i 's/^#\?Port .*/Port NOWY_PORT/' /etc/ssh/sshd_config"
ssh -p PORT USER@IP "sudo sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config"
ssh -p PORT USER@IP "sudo sed -i 's/^#\?PermitEmptyPasswords .*/PermitEmptyPasswords no/' /etc/ssh/sshd_config"
ssh -p PORT USER@IP "sudo sed -i 's/^#\?MaxAuthTries .*/MaxAuthTries 3/' /etc/ssh/sshd_config"
ssh -p PORT USER@IP "sudo sed -i 's/^#\?X11Forwarding .*/X11Forwarding no/' /etc/ssh/sshd_config"
ssh -p PORT USER@IP "sudo sed -i 's/^#\?ClientAliveInterval .*/ClientAliveInterval 300/' /etc/ssh/sshd_config"
ssh -p PORT USER@IP "sudo sed -i 's/^#\?ClientAliveCountMax .*/ClientAliveCountMax 2/' /etc/ssh/sshd_config"
```

Sprawdź konfigurację przed restartem:
```bash
ssh -p PORT USER@IP "sudo sshd -t"
```

Jeśli OK — dodaj nowy port do firewalla PRZED restartem SSH:
```bash
ssh -p PORT USER@IP "sudo ufw allow NOWY_PORT/tcp"
ssh -p PORT USER@IP "sudo systemctl restart ssh"
```

Przetestuj nowy port:
```bash
ssh -p NOWY_PORT USER@IP "echo 'NEW PORT OK'"
```

**Od tego momentu używaj NOWY_PORT.**

#### Krok 3: Firewall UFW (jeśli FAIL)
```bash
ssh -p PORT USER@IP "sudo apt-get install -y -qq ufw"
ssh -p PORT USER@IP "sudo ufw default deny incoming"
ssh -p PORT USER@IP "sudo ufw default allow outgoing"
ssh -p PORT USER@IP "sudo ufw allow SSH_PORT/tcp"
ssh -p PORT USER@IP "sudo ufw allow 80/tcp"
ssh -p PORT USER@IP "sudo ufw allow 443/tcp"
ssh -p PORT USER@IP "echo 'y' | sudo ufw enable"
ssh -p PORT USER@IP "sudo ufw status"
```

#### Krok 4: Fail2ban (jeśli FAIL)
```bash
ssh -p PORT USER@IP "sudo apt-get install -y -qq fail2ban"
```

Stwórz konfigurację:
```bash
ssh -p PORT USER@IP "sudo tee /etc/fail2ban/jail.local > /dev/null << 'JAILEOF'
[DEFAULT]
bantime = 86400
findtime = 3600
maxretry = 3
banaction = ufw

[sshd]
enabled = true
port = SSH_PORT
filter = sshd
logpath = /var/log/auth.log
JAILEOF"
ssh -p PORT USER@IP "sudo systemctl enable fail2ban && sudo systemctl restart fail2ban"
ssh -p PORT USER@IP "sudo fail2ban-client status sshd"
```

#### Krok 5: Wyłącz IPv6 (jeśli FAIL)
```bash
ssh -p PORT USER@IP "sudo tee /etc/sysctl.d/99-disable-ipv6.conf > /dev/null << 'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF"
ssh -p PORT USER@IP "sudo sysctl -p /etc/sysctl.d/99-disable-ipv6.conf"
```

#### Krok 6: ClamAV (jeśli FAIL)
Zapytaj użytkownika — ClamAV wymaga ~2GB RAM. Jeśli mały VPS, pomiń.
```bash
ssh -p PORT USER@IP "sudo apt-get install -y -qq clamav clamav-daemon"
ssh -p PORT USER@IP "sudo systemctl stop clamav-freshclam && sudo freshclam && sudo systemctl start clamav-freshclam"
ssh -p PORT USER@IP "sudo systemctl enable clamav-freshclam"
```

#### Krok 7: Log monitoring (jeśli FAIL)
```bash
ssh -p PORT USER@IP "sudo apt-get install -y -qq logwatch"
ssh -p PORT USER@IP "sudo mkdir -p /etc/logwatch/conf /var/log/logwatch"
```

#### Krok 8: Auto-updates (jeśli FAIL)
```bash
ssh -p PORT USER@IP "sudo apt-get install -y -qq unattended-upgrades apt-listchanges"
ssh -p PORT USER@IP "sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null << 'EOF'
APT::Periodic::Update-Package-Lists \"1\";
APT::Periodic::Unattended-Upgrade \"1\";
APT::Periodic::AutocleanInterval \"7\";
EOF"
```

### Faza 4: Weryfikacja

Uruchom audyt ponownie:
```bash
ssh -p FINAL_PORT FINAL_USER@IP "bash /tmp/audit.sh"
```

Pokaż porównanie: co było FAIL, co jest teraz PASS.

Powiedz: "Twój serwer jest zabezpieczony! Oto podsumowanie zmian:"
- Nowy użytkownik: X
- Port SSH: X
- Root login: wyłączony
- Firewall: aktywny
- Fail2ban: aktywny
- itd.

### Faza 5: Aktualizacja SSH config (lokalnie)

Zapytaj użytkownika czy chce dodać alias do ~/.ssh/config:
```
Host nazwa
    HostName IP
    User NOWY_USER
    Port NOWY_PORT
    IdentityFile ~/.ssh/id_ed25519
```

## WAŻNE

- **Hasło** — użyj TYLKO do sshpass w fazie 1. Po skopiowaniu klucza SSH, nigdy więcej nie używaj hasła.
- **Przed zmianą portu SSH** — ZAWSZE najpierw dodaj nowy port do UFW, potem restart SSH.
- **Przed wyłączeniem root** — ZAWSZE przetestuj nowego usera.
- **Bash guard** — komendy SSH mogą być blokowane przez bash-guard hook. Jeśli tak, poinformuj użytkownika.
- Każdy krok raportuj: co robisz, co się udało, co dalej.
- Jeśli coś failuje — nie idź dalej. Pokaż error i zapytaj co robić.
