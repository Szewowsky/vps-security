# /audit — Audyt bezpieczeństwa VPS

Sprawdź obecny stan zabezpieczeń serwera.

## Instrukcje

1. Zapytaj o dane serwera (IP, port SSH, użytkownik)

2. Skopiuj skrypt audytu na serwer:
   ```bash
   scp -P PORT scripts/audit.sh user@IP:/tmp/
   ```

3. Uruchom audyt:
   ```bash
   ssh -p PORT user@IP "sudo bash /tmp/audit.sh"
   ```

4. Przeanalizuj wyniki i podsumuj:
   - Co jest OK (PASS)
   - Co wymaga uwagi (FAIL/WARN)
   - Które skrypty uruchomić żeby naprawić

5. Zaproponuj kolejne kroki — podaj konkretne numery skryptów.
