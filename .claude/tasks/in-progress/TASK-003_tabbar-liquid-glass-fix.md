# TASK-003: TabBar — naprawa Liquid Glass i przejść

**Status**: ready-to-work
**Created**: 2026-04-26
**Size**: small
**Priority**: medium

---

## Opis

TabBar niepoprawnie korzysta z Liquid Glass (iOS 26 design system). Trzeba zweryfikować co jest nie tak, czy przejścia między tabami są prawidłowe, naprawić i potwierdzić na symulatorze.

## Kryteria akceptacji

- [ ] Zidentyfikowano konkretny błąd z Liquid Glass w TabBar
- [ ] Przejścia między tabami działają płynnie i zgodnie z iOS 26 HIG
- [ ] Wizualnie TabBar wygląda poprawnie na symulatorze (screenshot)
- [ ] Testy przechodzą (`test_sim`)

## Zależności

- Depends on: brak
- Blocks: brak

## Uwagi

- Sprawdź iOS 26 TabView / Tab API — Liquid Glass wymaga specyficznego podejścia (nie zwykły `tabViewStyle`)
- Użyj Context7 + WebSearch dla SwiftUI TabView iOS 26 Liquid Glass
- Zrób screenshot przed i po

## Guides do wczytania przed startem

- [ ] `.claude/guides/xcodebuild-mcp/GUIDE.md`
- [ ] `.claude/guides/architecture/GUIDE.md`
