---
phase: 03-quick-sessions
plan: "01"
subsystem: Session/Repository
tags: [domain-models, repository, persistence, combine, tdd]
dependency_graph:
  requires:
    - "02-02: BlocklistRepository (App Group atomic-write pattern mirrored)"
    - "02-01: Blocklist.id (UUID) referenced by SessionRecord.blocklistId"
  provides:
    - SessionOutcome (enum)
    - SessionDuration (struct)
    - SessionRecord (struct)
    - SessionFinalizeMarker (struct)
    - SessionPaths (enum)
    - SessionRepository (protocol + SessionRepositoryImpl)
  affects:
    - "03-02: SessionEnforcer consumes SessionRecord.plannedEndAt for DAS schedule"
    - "03-03: StartSession/EndSession UseCases wrap SessionRepository mutations"
    - "03-04: DAM extension reads active_session.json + writes session_finalize_marker.json via SessionPaths"
    - "03-05: CountdownViewModel observes activeSessionPublisher"
    - "03-06: AppRoot self-heal calls loadActiveSessionFromDisk + consumeFinalizeMarker"
tech_stack:
  added:
    - "Combine: CurrentValueSubject<SessionRecord?, Never> + CurrentValueSubject<[SessionRecord], Never>"
    - "os.Logger: scalar-only privacy (.public on UUIDs, counts, outcome rawValue)"
  patterns:
    - "Dual-file JSON persistence: active_session.json (singleton) + sessions.json (history array)"
    - "Atomic write: Data.write(to:options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])"
    - "Test seam via URL provider closures (no real App Group required in XCTest)"
    - "Typed publisher helpers in tests to avoid AnyPublisher<T?, Never> double-optional ambiguity"
key_files:
  created:
    - DeluluDetox/Sources/Features/Session/Repository/Models/SessionOutcome.swift
    - DeluluDetox/Sources/Features/Session/Repository/Models/SessionDuration.swift
    - DeluluDetox/Sources/Features/Session/Repository/Models/SessionRecord.swift
    - DeluluDetox/Sources/Features/Session/Repository/Models/SessionFinalizeMarker.swift
    - DeluluDetox/Sources/Features/Session/Repository/Models/SessionPaths.swift
    - DeluluDetox/Sources/Features/Session/Repository/SessionRepository.swift
    - DeluluDetoxTests/Features/Session/SessionRecordTests.swift
    - DeluluDetoxTests/Features/Session/SessionRepositoryTests.swift
  modified: []
decisions:
  - "Typed publisher helpers in SessionRepositoryTests instead of generic currentValue<Output> to avoid AnyPublisher<SessionRecord?, Never> wrapping Output? as SessionRecord?? causing XCTAssertNil and SwiftUI .id(_:) ambiguity under Swift 6"
  - "SessionPaths.PathError nested inside SessionPaths enum (not promoted to module-level) to keep the API surface minimal"
metrics:
  duration_minutes: 8
  completed_date: "2026-04-19"
  tasks_completed: 2
  files_created: 8
  files_modified: 0
  tests_added: 21
  test_results: "70 total, 3 skipped, 0 failures"
---

# Phase 03 Plan 01: Session Domain Models + Repository Summary

**One-liner:** JSON two-file session persistence (active_session.json + sessions.json) via CurrentValueSubject-backed repository with atomic writes, URL-provider test seam, and destructive finalize-marker consumption.

## What Was Built

### Task 1: Session domain models + unit tests (commit b1ab673)

Six source files under `DeluluDetox/Sources/Features/Session/Repository/Models/`:

- **SessionOutcome** — 3-case enum with snake_case raw values (`"completed"`, `"cancelled_by_user"`, `"broken_by_revoke"`) per CONTEXT D-08/D-14.
- **SessionDuration** — validated wrapper: `init?(seconds:)` returns nil outside 5 min–8 h; four `preset(_:)` convenience constructors for QSN-01 chips (15/30/60/90 min).
- **SessionRecord** — full Codable/Equatable/Identifiable/Sendable schema from day 1: `id`, `blocklistId`, `startedAt`, `plannedEndAt`, `plannedDurationSeconds`, `actualEndAt?`, `outcome?`, `appVersion`. `isActive` computed property.
- **SessionFinalizeMarker** — DAM → main-app handoff payload (CONTEXT D-03): `sessionId`, `finalizedAt`, `source` (`.damIntervalDidEnd` / `.damError`).
- **SessionPaths** — App Group URL helpers shared with DAM extension; no SwiftUI/Combine imports (extension-safe).
- **SessionRecordTests** — 12 unit tests: all pass.

### Task 2: SessionRepository protocol + impl + integration tests (commit a7a448d)

Two files:

- **SessionRepository.swift** — protocol + `SessionStoreError` + `SessionRepositoryImpl` (mirrors `BlocklistRepositoryImpl` shape). Two `CurrentValueSubject`s: `activeSubject: CurrentValueSubject<SessionRecord?, Never>` and `historySubject: CurrentValueSubject<[SessionRecord], Never>`. Production `init()` resolves App Group container via `SessionPaths`. Test-seam `init(activeURLProvider:historyURLProvider:markerURLProvider:appVersion:)`.
- **SessionRepositoryTests** — 9 integration tests: all pass. Uses typed helpers (`currentActiveSession(from:)` / `currentHistory(from:)`) to sidestep Swift 6 `AnyPublisher<T?, Never>` double-optional ambiguity.

## Test Results

```
Test Suite 'SessionRecordTests' passed — Executed 12 tests, 0 failures
Test Suite 'SessionRepositoryTests' passed — Executed 9 tests, 0 failures
Test Suite 'All tests' passed — Executed 70 tests, 3 skipped, 0 failures
```

Phase 02 baseline (49 tests + 3 skipped) fully preserved. 21 new Phase 3 tests added.

## Acceptance Criteria Grep Checklist

| Check | Status |
|-------|--------|
| `enum SessionOutcome: String, Codable, Sendable` | PASS |
| `struct SessionDuration: Codable, Equatable, Sendable` | PASS |
| `struct SessionRecord: Codable, Equatable, Identifiable, Sendable` | PASS |
| `struct SessionFinalizeMarker: Codable, Equatable, Sendable` | PASS |
| `enum SessionPaths` | PASS |
| `"group.com.kksw.DeluluDetox"` in SessionPaths | PASS |
| `protocol SessionRepository: Sendable` | PASS |
| `final class SessionRepositoryImpl: SessionRepository, @unchecked Sendable` | PASS |
| `CurrentValueSubject<SessionRecord?, Never>` | PASS |
| `CurrentValueSubject<[SessionRecord], Never>` | PASS |
| `options: [.atomic` in writeAtomic | PASS |
| `import SwiftUI` in Repository/Models tree | 0 occurrences — PASS |
| `import FamilyControls` in Repository/Models tree | 0 occurrences — PASS |
| `import ManagedSettings` in Repository tree | 0 occurrences — PASS |
| `xcodegen generate` produces zero project.yml diff | PASS |
| Full `xcodebuild test` green | PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed AnyPublisher<SessionRecord?, Never> double-optional ambiguity in tests**
- **Found during:** Task 2, first test run
- **Issue:** The generic `currentValue<Output>(of:)` helper returns `Output?` where `Output = SessionRecord?`, yielding `SessionRecord??`. Accessing `.id` on `SessionRecord??` was resolved by Swift 6 as SwiftUI's `.id(_:)` view modifier instead of `Identifiable.id`, causing a compile error. `XCTAssertNil` on `SessionRecord??` also failed silently (outer optional was `.some(.none)`, not `nil`).
- **Fix:** Replaced the single generic helper with two typed helpers `currentActiveSession(from:) -> SessionRecord?` and `currentHistory(from:) -> [SessionRecord]` that operate directly on the concrete publisher type, eliminating the double-optional entirely.
- **Files modified:** `DeluluDetoxTests/Features/Session/SessionRepositoryTests.swift`
- **Commit:** a7a448d

## Known Stubs

None — all repository operations are fully wired. Publishers emit real data from disk-backed JSON files.

## Threat Flags

No new network endpoints, auth paths, or trust boundaries introduced beyond what the plan's threat model (`T-03-01-01` through `T-03-01-06`) already covers. All mitigations implemented as specified.

## Next Steps

- **P02 (wave 1, parallel):** SessionEnforcer — ManagedSettings + DeviceActivityCenter wrapper using `SessionRecord.plannedEndAt` for DAS schedule end.
- **P03 (wave 2):** StartSession + EndSession + FinalizeSessionFromMarker UseCases wrap `SessionRepository` mutations and inject into DI.
- **P04 (wave 2, parallel):** DAM extension reads `SessionPaths.activeSessionURL()` and writes `SessionFinalizeMarker` to `SessionPaths.finalizeMarkerURL()`.

## Self-Check: PASSED

All 8 source/test files found on disk. Commits b1ab673 and a7a448d verified in git log. Full test suite: 70 tests, 3 skipped, 0 failures.
