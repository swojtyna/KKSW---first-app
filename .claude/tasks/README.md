# Jak pracować z taskami

## Tworzenie taska

Powiedz Claudowi co chcesz zrobić — on sam stworzy TASK plik i zacznie pracę.

Przykłady:
- "Zaimplementuj ekran wyboru aplikacji"
- "Napraw bug z licznikiem czasu"
- "Dodaj obsługę błędów w SessionRepository"

Claude oceni czy zadanie jest małe (jeden plik) czy duże (wiele kroków/sesji) i stworzy odpowiednią strukturę.

---

## Ręczne tworzenie taska (opcjonalnie)

Jeśli chcesz zaplanować task przed wykonaniem, skopiuj szablon:

```
cp .claude/tasks/TASK-TEMPLATE.md .claude/tasks/ready-to-work/TASK-NNN_slug.md
```

Wypełnij i powiedz Claudowi żeby go wziął.

---

## Wykonanie taska

Wskaż task który ma być zrobiony:

- "Weź TASK-002"
- "Zrób task z wyborem aplikacji"
- "Kontynuuj TASK-003, phase-02"

Claude przeniesie task do `in-progress/`, wykona pracę, przeniesie do `done/`.

---

## Duże taski (wiele sesji)

Dla dużych zadań Claude tworzy:
```
ready-to-work/
├── TASK-NNN_slug.md          # opis całości
└── TASK-NNN_files/
    ├── MASTERPLAN.md          # plan wszystkich faz
    ├── phase-01.md            # faza 1
    └── phase-02.md            # faza 2
```

Każda faza = jeden kontekst czatu. W nowym czacie powiedz:
- "Kontynuuj TASK-003, jesteś na phase-02"

---

## Sprawdzanie statusu

- Zajrzyj do `.claude/tasks/STATUS.md` — lista wszystkich tasków
- Lub zapytaj: "Co mamy do zrobienia?" / "Jaki jest status tasków?"

---

## Numery tasków

Format: `TASK-001`, `TASK-002`, `TASK-003` (zawsze 3 cyfry).  
Kolejny numer to MAX z istniejących + 1. Sprawdź `STATUS.md` żeby wiedzieć gdzie jesteś.
