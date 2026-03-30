# Instrukcja — first konfig OpenClaw na Hostinger VPS

1. Zainstaluj OpenClaw przez **hPanel → Docker Manager → Catalog → OpenClaw**

2. Utwórz bota Telegram przez BotFather (`/newbot`) i zapisz token

3. Odpal konsolę i sprawdź nazwę kontenera z OpenClaw:
```
docker ps
```

4. Wejdź do kontenera:
```
docker exec -it [nazwa] bash
```

5. Przejdź przez pełny onboarding:
```
openclaw onboard
```

6. Podczas wizarda podaj token Telegrama i klucz Brave API / Tavily API (jeśli chcesz web search)

7. W nowym terminalu wyłącz hook session-memory (powoduje błąd Anthropic):
```
docker exec [nazwa] bash -c "cat /data/.openclaw/openclaw.json | sed 's/\"session-memory\": {\"enabled\": true}/\"session-memory\": {\"enabled\": false}/' > /tmp/openclaw_new.json && cp /tmp/openclaw_new.json /data/.openclaw/openclaw.json"
```

8. Zrestartuj kontener:
```
docker restart [nazwa]
```

9. Wyślij dowolną wiadomość na Telegramie do swojego bota → odpal terminal (konsolę) → wejdź ponownie do kontenera i zatwierdź parowanie Telegrama:
```
docker exec -it [nazwa] bash
openclaw pairing list telegram
openclaw pairing approve telegram [KOD]
```

10. Otwórz nowy terminal i zrestartuj kontener:
```
docker restart [nazwa]
```

## Dodatkowo

- **Strefa czasowa:** W pliku `.env` zmień zmienną `TZ` na `Europe/Warsaw`
- **OpenAI API:** Dodaj zmienną środowiskową `OPENAI_API_KEY` i w polu "Wartość" wpisz klucz API wygenerowany na https://platform.openai.com
- Zapisz zmiany i poczekaj aż VPS uruchomi się ponownie :)
