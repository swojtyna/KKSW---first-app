---
description: Conversational UAT — map each ROADMAP Success Criterion to Pass/Fail/Skip/Defer via AskUserQuestion, produce VERIFICATION.md
argument-hint: <N>
allowed-tools: [Read, Write, Edit, AskUserQuestion, Grep, Glob]
---

# /phase-verify

Conversational UAT — user przechodzi przez każdy Success Criterion z ROADMAP Phase N i odpowiada `Pass` / `Fail` / `Skip` / `Defer`. Jeśli `Fail` → user podaje gap description.

Output: `<NN>-VERIFICATION.md` + `overall_status` (passed | partial | failed).

## Arguments

- `<N>` (required) — numer fazy.

## Process

### 1. Resolve phase + read inputs

```
Glob .planning/phases/{N}-*/{NN}-PLAN.md
Glob .planning/phases/{N}-*/{NN}-SUMMARY.md
```

Jeśli SUMMARY.md brak → BLOCK: `Phase {N} not yet executed. Run /phase-do {N} first.`

Read:
- `.planning/ROADMAP.md` §Phase N — zwłaszcza Success Criteria (numbered list)
- `{NN}-PLAN.md` — `<success_criteria>` sekcja (mapping SC → T)
- `{NN}-SUMMARY.md` — Accomplishments + Acceptance Criteria Matrix

### 2. Parse Success Criteria

Z ROADMAP `### Phase N:` sekcji wydobądź numerowaną listę **Success Criteria**.

Przykład Phase 04:
```
1. Shield overlay displays custom DeluluDetox branding
2. Shield shows a sensible fallback design when encountering unknown/unexpected tokens
3. Shield has a button that deep links to the main app
4. Main app receives the deep link and navigates to the relevant active session context
```

### 3. Per-criterion AskUserQuestion

Per SC:

```
AskUserQuestion:
  question: "SC-{N}: {criterion}"
  context: "{mapping z PLAN.md — np. 'zrealizowane przez T01, T03'}"
  options:
    - Pass — działa w praktyce (testowane w simulator lub on-device)
    - Fail — nie działa / częściowo / błąd
    - Skip — not testable (np. wymaga physical device i entitlement Apple approval pending)
    - Defer — świadomie przesuwamy do późniejszej fazy / post-MVP
```

Jeśli `Fail`:
```
AskUserQuestion:
  question: "Opisz gap dla SC-{N}:"
  fields:
    - gap_description: textarea
    - impact: select [high | medium | low]
```

Jeśli `Skip` lub `Defer`:
```
AskUserQuestion:
  question: "Reason / plan for {Skip|Defer}:"
  fields:
    - reason: text
```

### 4. Compute overall_status

- Wszystkie `Pass` → `passed`
- Jakikolwiek `Fail` → `failed` (BLOKUJE `/phase-ship` by default)
- Tylko `Pass` + `Skip` + `Defer` → `partial` (nie blokuje `/phase-ship`, ale user musi świadomie zaakceptować partial w shipie)

### 5. Write VERIFICATION.md

Read `.planning/templates/VERIFICATION.md` → wypełnij:

- Frontmatter: `phase`, `date`, `overall_status`
- Table Success Criteria Matrix z odpowiedziami
- `<gaps>` sekcja (tylko jeśli są fails):
  - Per fail: criterion + user description + impact + proposed resolution
- `<followup>` sekcja (tylko jeśli fails / skips / defers):
  - Option A: gap-fix w tej fazie (re-run `/phase-plan {N}` z dodatkowym taskiem)
  - Option B: backlog (new phase via `/phase-add`)
  - Option C: defer do post-MVP (update PROJECT.md §Out of Scope)

### 6. Suggest follow-up

#### 6a. Jeśli `passed`:
```
✓ Phase {N} verified — all {N} success criteria passed.
  VERIFICATION.md: {PHASE_DIR}/{NN}-VERIFICATION.md

Następny krok: /phase-ship {N}
```

#### 6b. Jeśli `partial`:
```
⚠ Phase {N} partial — {X/Y} passed, {Z} skipped/deferred (no fails).
  Skip: SC-{i} — {reason}
  Defer: SC-{j} — {reason}

Możesz:
  - Zakończyć fazę z partial status: /phase-ship {N} (wymaga potwierdzenia)
  - Retry skipped SC (np. po Apple approval): re-run /phase-verify {N} po testach
```

#### 6c. Jeśli `failed`:
```
🚫 Phase {N} failed — {Y} gap(s) detected.
  Fails:
    SC-{i}: {criterion}
      Gap: {description}
      Impact: {level}

Proposed resolutions:
  - Gap-fix w tej fazie: /phase-plan {N} — doda gap-fix tasks do istniejącego planu
  - Backlog nowej fazy: /phase-add --after {N} {gap-fix-slug}
  - Defer do post-MVP: update PROJECT.md §Out of Scope
```

### 7. Commit

```bash
git add {PHASE_DIR}/{NN}-VERIFICATION.md
git commit -m "docs({N}): verification {overall_status}"
```

## Constraints

- Zero Task spawn. Pure conversational flow.
- `overall_status = failed` BLOKUJE `/phase-ship` by default (user może override).
- Jeśli VERIFICATION.md już istnieje → AskUserQuestion: `Update / View / Skip` (idempotency per discuss-phase pattern).
- Nie bada automatycznie acceptance criteria z PLAN/SUMMARY — one są task-level, już sprawdzone w `/phase-do`. Verify jest **user-level UAT** — "czy naprawdę działa tak jak obiecałem".
