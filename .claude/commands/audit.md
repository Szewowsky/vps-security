# /audit — Audyt bezpieczeństwa VPS

Sprawdź obecny stan zabezpieczeń serwera.

## WAŻNE ZASADY

1. **NIE próbuj sam łączyć się przez SSH** — mów użytkownikowi co wpisać z prefixem `!`
2. Jedna komenda na raz, czekaj na output

## Workflow

1. Powiedz użytkownikowi żeby się połączył:
   "Wpisz: `! ssh -p PORT user@IP`"

2. Pobierz skrypty jeśli ich jeszcze nie ma:
   "Wpisz: `! git clone https://github.com/Szewowsky/vps-security.git /tmp/vps-security`"
   (Jeśli już sklonowane, pomiń)

3. Uruchom audyt:
   "Wpisz: `! bash /tmp/vps-security/scripts/audit.sh`"

4. Przeanalizuj output i podsumuj:
   - Co jest OK (PASS) — pochwal
   - Co wymaga uwagi (FAIL/WARN)
   - Które skrypty uruchomić żeby naprawić (podaj konkretne numery)

5. Zapytaj czy chce od razu naprawić — jeśli tak, zaproponuj `/hardening`
