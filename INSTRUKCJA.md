# Jak zabezpieczyć swój VPS — krok po kroku

Nie musisz być programistą. Potrzebujesz tylko:
- Serwer VPS z Ubuntu (np. Hostinger, DigitalOcean)
- Terminal na komputerze (Terminal na Macu, PowerShell na Windows)
- 30 minut czasu

## Zanim zaczniesz

Podłącz się do swojego serwera:

```
ssh root@TWOJE_IP
```

Jeśli masz inny port (np. 2222):

```
ssh -p 2222 root@TWOJE_IP
```

Jeśli nie wiesz jak się podłączyć — sprawdź panel swojego hostingu. Tam będzie opcja "Terminal" lub "SSH access".

## Pobierz skrypty na serwer

Będąc na serwerze, wpisz:

```
apt install git -y
git clone https://github.com/Szewowsky/vps-security.git /tmp/vps-security
cd /tmp/vps-security/scripts
```

## Sprawdź co masz (audyt)

```
bash audit.sh
```

Zobaczysz raport — zielone = OK, czerwone = do zrobienia. Zapamiętaj co jest czerwone.

---

## Krok 1: Stworzenie bezpiecznego użytkownika

**Po co?** Logowanie jako "root" (admin) to jak chodzenie z kluczem generalnym — jedno złe polecenie i cały serwer padnie. Lepiej mieć zwykłego użytkownika, który prosi o pozwolenie (sudo) przed niebezpiecznymi rzeczami.

```
bash 01-create-user.sh
```

Skrypt zapyta o:
- **Nazwę użytkownika** — wymyśl cokolwiek (np. `janek`, `admin2`)

Potem powie Ci: **"Otwórz nowy terminal i przetestuj logowanie"**.

To NAJWAŻNIEJSZY moment. Otwórz DRUGI terminal i spróbuj:

```
ssh -p TWOJ_PORT twoj_user@TWOJE_IP
```

Działa? Super — wróć do pierwszego terminala i wpisz `tak`.

Nie działa? Wpisz `nie` — skrypt nie wyłączy starego logowania.

⚠️ **NIE zamykaj pierwszego terminala dopóki nie sprawdzisz!**

---

## Krok 2: Zabezpieczenie SSH

**Po co?** SSH to drzwi do Twojego serwera. Domyślnie stoją na porcie 22 i boty próbują je wyważyć non-stop. Zmieniamy port i zamykamy kilka dziur.

```
bash 02-harden-ssh.sh
```

Skrypt zapyta o:
- **Nowy port SSH** — wpisz liczbę np. `2222`, `4321`, `5555` (cokolwiek między 1024 a 65535)

Po zmianie portu — znowu **testuj w nowym terminalu**:

```
ssh -p NOWY_PORT twoj_user@TWOJE_IP
```

⚠️ Jeśli zmienisz port, musisz go dodać do firewalla (krok 3) — inaczej się zablokujesz!

---

## Krok 3: Firewall (zapora sieciowa)

**Po co?** Wyobraź sobie serwer jak dom z setkami drzwi. Firewall zamyka wszystkie oprócz tych, które naprawdę potrzebujesz (SSH, strona www).

```
bash 03-setup-firewall.sh
```

Skrypt zapyta:
- **Czy otworzyć porty 80 i 443?** — tak, jeśli masz na serwerze stronę/aplikację
- **Dodatkowe porty** — np. jeśli masz coś na porcie 8080

---

## Krok 4: Fail2ban (ochrona przed atakami)

**Po co?** Ktoś próbuje odgadnąć hasło do Twojego serwera — próbuje raz, dwa, trzy... Fail2ban po 3 nieudanych próbach blokuje ten adres IP na 24 godziny.

```
bash 04-setup-fail2ban.sh
```

Skrypt zapyta:
- **Ile prób przed banem** — domyślnie 3 (zostaw)
- **Jak długi ban** — domyślnie 24h (zostaw)

---

## Krok 5: Wyłączenie IPv6

**Po co?** IPv6 to nowa wersja adresów internetowych. Większość serwerów jej nie używa, a każdy włączony protokół to potencjalna dziura. Nie używasz? Wyłącz.

```
bash 05-disable-ipv6.sh
```

Nic nie pyta — po prostu wyłącza.

---

## Krok 6: Antywirus (ClamAV)

**Po co?** Tak jak na komputerze — skanuje pliki pod kątem wirusów i malware.

```
bash 06-setup-clamav.sh
```

⚠️ **Uwaga:** Potrzebuje ~2GB RAM. Jeśli masz mały serwer (1GB) — pomiń ten krok.

Skrypt zapyta:
- **Czy uruchomić skan teraz?** — tak, warto sprawdzić na start

---

## Krok 7: Monitoring logów

**Po co?** Bez logów nie wiesz, kto próbował się włamać ani co się dzieje na serwerze. Ten skrypt instaluje automatyczny codzienny raport.

```
bash 07-log-monitoring.sh
```

Nic nie pyta — konfiguruje i pokazuje przykładowy raport.

---

## Krok 8: Automatyczne aktualizacje

**Po co?** Ubuntu regularnie wydaje poprawki bezpieczeństwa. Ten skrypt sprawia, że instalują się automatycznie — nie musisz o tym pamiętać.

```
bash 08-auto-updates.sh
```

Skrypt zapyta:
- **Automatyczny restart po aktualizacjach?** — `nie` jeśli masz na serwerze ważne rzeczy, które muszą działać 24/7

---

## Gotowe!

Uruchom audyt ponownie:

```
bash audit.sh
```

Teraz powinno być dużo więcej zielonego. Gratulacje — Twój serwer jest zabezpieczony!

---

## Coś poszło nie tak?

### Nie mogę się zalogować!
1. Wejdź do panelu swojego hostingu (np. Hostinger → hPanel)
2. Znajdź opcję "Terminal" lub "VPS Access"
3. Zaloguj się przez przeglądarkę
4. Napraw: `nano /etc/ssh/sshd_config`
5. Restart: `systemctl restart ssh`

### Fail2ban zbanował moje IP
```
sudo fail2ban-client set sshd unbanip TWOJE_IP
```

### ClamAV zjada za dużo pamięci
```
sudo systemctl stop clamav-daemon
```
I skanuj ręcznie gdy potrzebujesz: `sudo clamscan -r /home`

---

Materiał towarzyszący do filmu: [Robert Szewczyk](https://youtube.com/@robert_szewczyk)
