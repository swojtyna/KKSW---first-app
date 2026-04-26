# TASK-002: SwiftUINavigation — analiza, naprawa, refaktor

**Status**: ready-to-work
**Created**: 2026-04-26
**Size**: large
**Priority**: high

---

## Opis

Obecne użycie `SwiftUINavigation` / `import SwiftUINavigation` wymaga weryfikacji. Trzeba zbadać jak biblioteka powinna być używana (oficjalna dokumentacja, przykłady z innych projektów), zaktualizować guide nawigacji, a następnie poprawić projekt. Dodatkowo użytkownik nie jest zadowolony z tego że cała logika nawigacji siedzi w ViewModelu — przed implementacją należy przedstawić 3 propozycje + 1 rekomendację jak to zmienić.

## Kryteria akceptacji

- [ ] Analiza użycia biblioteki ukończona (Context7 + WebSearch)
- [ ] 3 propozycje + 1 rekomendacja dot. miejsca logiki nawigacji przedstawione użytkownikowi
- [ ] Podejście zatwierdzone przez użytkownika przed implementacją
- [ ] `.claude/guides/navigation/GUIDE.md` zaktualizowany
- [ ] Wszystkie ViewModele w projekcie używają biblioteki zgodnie z zatwierdzonym wzorcem
- [ ] Testy przechodzą (`test_sim`)

## Zależności

- Depends on: brak
- Blocks: brak

## Uwagi

- Użyj Context7 + WebSearch do zbadania `pointfreeco/swift-navigation` — jak inni to używają, co jest wzorcem
- Kluczowe pytanie do propozycji: czy nawigacja zostaje w ViewModelu (@Observable Destination enum), czy przenosi się gdzieś indziej (np. dedykowany Router, Coordinator, widok-owner)
- Sprawdź jak `@CasePathable` jest używane w aktualnym projekcie

## Guides do wczytania przed startem

- [ ] `.claude/guides/navigation/GUIDE.md` ← primary
- [ ] `.claude/guides/architecture/GUIDE.md`
- [ ] `.claude/guides/feature-structure/GUIDE.md`
- [ ] `.claude/guides/xcodebuild-mcp/GUIDE.md`
