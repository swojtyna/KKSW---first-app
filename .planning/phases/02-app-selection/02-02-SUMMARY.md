---
phase: 02
plan: 02
subsystem: app-selection
tags:
  - wave-2
  - foundation
  - repository
  - persistence
  - familycontrols
  - combine
  - codable
requirements:
  - SEL-01
  - SEL-02
  - SEL-03
  - SEL-04
  - SEL-05
dependency_graph:
  requires:
    - Plan 02-01 Wave 0 spikes (A1 JSON round-trip green + A2 compile guard green)
    - Phase 01.1 feature-first layout (DeluluDetox/Sources/Features/ root)
    - DeluluDetox.entitlements — App Group group.com.kksw.DeluluDetox
  provides:
    - TokenKind / TokenRecord / Blocklist domain types (Codable, Sendable, Identifiable)
    - BlocklistRepository protocol + BlocklistRepositoryImpl with CurrentValueSubject + atomic JSON write
    - fileURLProvider test seam for tempdir-based integration tests
    - Blocklist.merging(selection:) — single source of record-creation truth for Plan 03 UpdateBlocklistUseCase
  affects:
    - Plan 02-03 UpdateBlocklistUseCaseImpl — will inject BlocklistRepository
    - Plan 02-04 AppSelectionViewModel — will observe blocklistPublisher
    - Plan 02-06 PickerHostView — consumes records for Label(token) rendering via TokenRecord.applicationToken() etc.
    - Plan 02-07 device human-verify — will exercise persistence across launches end-to-end
    - Phase 3 StartSessionUseCase — read-only consumer of the JSON file contract
    - Phase 5 DeviceActivityMonitor extension — read-only consumer from App Group
tech_stack:
  added: []
  patterns:
    - "@preconcurrency import FamilyControls — required on Swift 6.2 because FamilyActivitySelection is not Sendable in iOS 26.3 SDK"
    - "CurrentValueSubject-backed repository with writeAndEmit pattern (mirrors ScreenTimeAuthRepositoryImpl)"
    - "fileURLProvider closure seam — production resolves App Group container, tests inject tempdir URL"
    - "Atomic file writes via Data.write(to:options:) with [.atomic, .completeFileProtectionUntilFirstUserAuthentication]"
    - "os.Logger scalar-only privacy — never log FamilyActivitySelection contents or raw token bytes"
key_files:
  created:
    - path: DeluluDetox/Sources/Features/AppSelection/Repository/Models/TokenKind.swift
      purpose: "Discriminator enum — .application / .category / .webDomain"
    - path: DeluluDetox/Sources/Features/AppSelection/Repository/Models/TokenRecord.swift
      purpose: "UUID-keyed Codable/Sendable record with per-kind token decoders (applicationToken / categoryToken / webDomainToken)"
    - path: DeluluDetox/Sources/Features/AppSelection/Repository/Models/Blocklist.swift
      purpose: "Codable aggregate with merging(selection:) + reconcileTokenPointers() — single source of record-creation truth"
    - path: DeluluDetox/Sources/Features/AppSelection/Repository/BlocklistRepository.swift
      purpose: "Protocol + impl with CurrentValueSubject<Blocklist, Never> + atomic JSON write to App Group container"
    - path: DeluluDetoxTests/Features/AppSelection/BlocklistTests.swift
      purpose: "8 unit tests — Codable round-trip, merging idempotency, record drop on selection change, reconcile updatedAt bump"
    - path: DeluluDetoxTests/Features/AppSelection/BlocklistRepositoryTests.swift
      purpose: "6 integration tests — fresh container fallback, atomic write+emit, persistence across instances, reconcile, remove, container unavailable"
  modified: []
decisions:
  - "Rule 3 deviation — @preconcurrency import FamilyControls added to Blocklist.swift and BlocklistRepository.swift. Swift 6.2 strict concurrency rejects lastSelection: FamilyActivitySelection inside a Sendable-conforming struct because Apple's iOS 26.3 SDK does not mark FamilyActivitySelection Sendable. @preconcurrency is the standard escape hatch (compiler-suggested) and does not weaken the Sendable contract on our types — Blocklist and BlocklistRepositoryImpl remain Sendable-conforming as the plan mandates."
  - "Rule 3 deviation (carried from Plan 02-01) — host's iPhone 17 simulator UUID is 6D73311F-3541-4B74-92E8-8014FABC3329, NOT the CLAUDE.md canonical C958163F-... (host-local detail). Used local UUID for all xcodebuild -destination invocations. No repo-level change."
  - "Rule 3 deviation (carried from Plan 02-01) — XcodeBuildMCP tools (session_show_defaults / build_sim / test_sim) not exposed in this runtime. Used raw xcodebuild via Bash with -skipMacroValidation and explicit -destination, mirroring the plan's <verify> block. All other CLAUDE.md conventions honored (xcodegen regenerated after every source-file addition, zero .xcodeproj hand-edits)."
metrics:
  completed_date: "2026-04-19"
  duration: "~12 minutes"
  tasks_completed: 2
  files_created: 6
  files_modified: 0
---

# Phase 02 Plan 02: AppSelection Blocklist Domain + Repository Summary

Foundation plan for Phase 02 — ships the four-file AppSelection domain (`TokenKind`, `TokenRecord`, `Blocklist`) and `BlocklistRepository` with atomic JSON persistence + Combine publisher, unblocking Plans 02-03 through 02-07.

## What Was Built

### Domain models (3 files under `DeluluDetox/Sources/Features/AppSelection/Repository/Models/`)

- **`TokenKind.swift`** — `enum TokenKind: String, Codable, Sendable` with cases `.application`, `.category`, `.webDomain`.
- **`TokenRecord.swift`** — `struct TokenRecord: Codable, Equatable, Identifiable, Sendable` with `id: UUID`, `kind: TokenKind`, `encodedToken: Data`, `lastSeenAt: Date`, and three kind-gated decoders (`applicationToken()`, `categoryToken()`, `webDomainToken()`) returning `nil` for mismatched kind.
- **`Blocklist.swift`** — `struct Blocklist: Codable, Equatable, Sendable` with `id`, `name`, `records`, `lastSelection: FamilyActivitySelection`, `updatedAt`, `needsRepair`; static `.empty(id:)` factory; `merging(selection:)` preserves existing record UUIDs for matching `encodedToken` bytes (SEL-05) and drops records whose tokens are not in the new selection; `reconcileTokenPointers()` bumps `updatedAt` and keeps record IDs intact (Phase 02 MVP scope).

### Repository (1 file + 1 test file)

- **`BlocklistRepository.swift`** — `protocol BlocklistRepository: Sendable` + `final class BlocklistRepositoryImpl: BlocklistRepository, @unchecked Sendable`. State held in `CurrentValueSubject<Blocklist, Never>`; `blocklistPublisher` exposes `AnyPublisher<Blocklist, Never>`. Mutation surface: `update(with:)`, `remove(recordID:)`, `reconcile()`. Production `init()` resolves `group.com.kksw.DeluluDetox` App Group container URL; test `init(fileURLProvider:)` injects tempdir URL. `writeAndEmit` performs atomic JSON write with `[.atomic, .completeFileProtectionUntilFirstUserAuthentication]` file-protection option. `readFromDisk` falls back to `Blocklist.empty()` on ENOENT or decode failure (Pitfall 7). `os.Logger` emits only scalar counts — no `FamilyActivitySelection` contents.
- **`BlocklistStoreError`** — single case `.containerUnavailable` surfaced when App Group container URL cannot be resolved.

### Tests (2 files, 14 tests total)

- **`BlocklistTests.swift`** — 8 unit tests: empty-blocklist invariants, Codable round-trip, merging-with-empty-selection drops all records, SEL-05 identity preservation path (negative-assertion flavor due to simulator token limitation), TokenRecord Codable round-trip, kind-mismatch nil decoder, reconcile `updatedAt` bump with record ID preservation.
- **`BlocklistRepositoryTests.swift`** — 6 integration tests: fresh-container empty fallback, update+write+emit, persistence across two repo instances against same URL (SEL-04), reconcile `updatedAt` bump on disk, remove by recordID drops matching record from disk, container-unavailable fallback to empty.

## Test Output Excerpt

Full suite (filtered excerpt below; run on iPhone 17 simulator UUID `6D73311F-3541-4B74-92E8-8014FABC3329`, iOS 26.3 SDK via Xcode 26.3):

```
Test Suite 'BlocklistTests' passed at 2026-04-19 13:14:55.106.
	 Executed 8 tests, with 0 failures (0 unexpected) in 0.022 (0.023) seconds

Test Suite 'BlocklistRepositoryTests' passed at 2026-04-19 13:16:38.425.
	 Executed 6 tests, with 0 failures (0 unexpected) in 0.031 (0.032) seconds

Test Suite 'DeluluDetoxTests.xctest' passed at 2026-04-19 13:16:48.230.
	 Executed 35 tests, with 3 tests skipped and 0 failures (0 unexpected) in 0.205 (0.213) seconds
Test Suite 'All tests' passed at 2026-04-19 13:16:48.231.
** TEST SUCCEEDED **
```

35 = 21 baseline (Phase 01.1 × 14 + Plan 02-01 × 7 incl. 3 device-seeded skips) + 8 BlocklistTests + 6 BlocklistRepositoryTests. Zero regressions in Phase 01.1 or Plan 02-01.

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 | `e8000a4` | `feat(02-02): ship Blocklist domain models + unit tests` |
| 2 | `785390d` | `feat(02-02): ship BlocklistRepository with atomic App Group persistence` |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking issue] `@preconcurrency import FamilyControls` required for Sendable conformance**

- **Found during:** Task 1 first build after model files landed.
- **Issue:** The plan declares `struct Blocklist: Codable, Equatable, Sendable` and requires `var lastSelection: FamilyActivitySelection` as a stored property. Swift 6.2 strict concurrency under Xcode 26.3 rejects this with:
  ```
  Stored property 'lastSelection' of 'Sendable'-conforming struct 'Blocklist'
  has non-Sendable type 'FamilyActivitySelection'
  ```
  `FamilyActivitySelection` in the iOS 26.3 SDK declares `Codable, Equatable` but does not declare `Sendable` (verified in `/Applications/Xcode-26.3.0.app/Contents/Developer/Platforms/.../FamilyControls.framework/Headers/FamilyActivitySelection.swiftinterface`).
- **Fix:** Prefixed the import with `@preconcurrency` in both `Blocklist.swift` and `BlocklistRepository.swift`. This is the compiler-suggested escape hatch and does NOT weaken the Sendable contract on our types — `Blocklist` and `BlocklistRepositoryImpl` remain Sendable-conforming per the plan's interface declaration.
- **Impact on plan:** None architecturally. The plan's `<interfaces>` block explicitly mandates `struct Blocklist: Codable, Equatable, Sendable` and `protocol BlocklistRepository: Sendable` — `@preconcurrency` is the minimum-surface change that satisfies those contracts against the current Apple SDK. When Apple ships `Sendable` conformance on `FamilyActivitySelection` (likely iOS 27+), the `@preconcurrency` prefix becomes a no-op and can be cleaned up.
- **Files modified:** `DeluluDetox/Sources/Features/AppSelection/Repository/Models/Blocklist.swift` (line 1), `DeluluDetox/Sources/Features/AppSelection/Repository/BlocklistRepository.swift` (line 2).
- **Commits:** Folded into `e8000a4` (Task 1) and `785390d` (Task 2) — pre-fix state never committed.

**2. [Rule 3 — Carry-over from Plan 02-01] Simulator UUID + XcodeBuildMCP absence**

- Host's iPhone 17 UUID is `6D73311F-3541-4B74-92E8-8014FABC3329`; the CLAUDE.md canonical `C958163F-...` is not present on this machine. Used the local UUID for all `xcodebuild -destination` invocations.
- XcodeBuildMCP tools (`session_show_defaults` / `build_sim` / `test_sim`) are not exposed in this runtime. Used raw `xcodebuild` via Bash with `-skipMacroValidation` and explicit `-destination`, exactly mirroring the plan's `<verify>` shape.
- Both deviations are environment-level (per-developer / per-runtime) and require no repo-level change. Documented in Plan 02-01 SUMMARY as well.

## Findings

- **SEL-05 at unit level is green.** `Blocklist.merging(selection:)` preserves existing record UUIDs when the incoming selection encodes the same `encodedToken` bytes — covered by the idempotent-refresh branch test. True Apple-token idempotency (where `FamilyActivityPicker` re-surfaces the same opaque token) is still device-only per Plan 02-01's simulator limitation and will be exercised end-to-end in Plan 02-07 human-verify.
- **SEL-04 at integration level is green.** `testPersistenceAcrossRepoInstances` proves a second `BlocklistRepositoryImpl` against the same `fileURLProvider` hydrates the previously-written `Blocklist.id` from disk. Production App Group container parity is a host-entitlement matter verified in Plan 02-07.
- **Repository write surface is single.** Only `writeAndEmit` mutates state — `update`, `remove`, `reconcile` all funnel through it. Prevents divergence between in-memory `blocklistSubject.value` and on-disk JSON (D-02 invariant).
- **Fresh-install ENOENT + corrupt-JSON both fall through to `Blocklist.empty()`.** `readFromDisk` returns `nil` on any throw (missing file, decode error, container unavailable) and `init` replaces with a fresh empty aggregate. No crash path on cold start.

## Acceptance Criteria Check

| Criterion | Status |
|-----------|--------|
| All 4 source files exist under `DeluluDetox/Sources/Features/AppSelection/Repository/` | PASS (TokenKind, TokenRecord, Blocklist, BlocklistRepository) |
| Grep `enum TokenKind: String, Codable, Sendable` in TokenKind.swift | PASS |
| Grep `struct TokenRecord: Codable, Equatable, Identifiable, Sendable` | PASS |
| Grep `struct Blocklist: Codable, Equatable, Sendable` | PASS |
| Grep `func merging(selection next: FamilyActivitySelection) -> Blocklist` | PASS |
| Grep `protocol BlocklistRepository: Sendable` | PASS |
| Grep `final class BlocklistRepositoryImpl: BlocklistRepository, @unchecked Sendable` | PASS |
| Grep `CurrentValueSubject<Blocklist, Never>` | PASS (lines 40, 67) |
| Grep `group.com.kksw.DeluluDetox` | PASS (line 30) |
| Grep `options: [.atomic` | PASS (line 96) |
| Grep `import SwiftUI` in Repository/ tree | PASS (0 matches) |
| `xcodegen generate` produces zero diff to project.yml | PASS |
| All 8 BlocklistTests methods PASS | PASS |
| All 6 BlocklistRepositoryTests methods PASS | PASS |
| Full test suite green (35 tests, 3 skipped, 0 failures) | PASS |
| `git diff` against baseline for Onboarding / Root / Home is empty | PASS |

## Next Steps

Plan 02-03 binds these types to the UseCase + DI layer:
- `UpdateBlocklistUseCaseImpl` will inject `BlocklistRepository` and call `update(with:)`.
- `AppSelectionInjection` will register `BlocklistRepositoryImpl` at `.application` scope in the DIContainer.
- No further writes to `Features/AppSelection/Repository/` should be needed until Plan 02-07 device human-verify (possibly to add telemetry or hardening discovered during end-to-end runs).

## Self-Check: PASSED

- [x] `DeluluDetox/Sources/Features/AppSelection/Repository/Models/TokenKind.swift` exists (Read-verified + git-tracked in `e8000a4`).
- [x] `DeluluDetox/Sources/Features/AppSelection/Repository/Models/TokenRecord.swift` exists (Read-verified + git-tracked in `e8000a4`).
- [x] `DeluluDetox/Sources/Features/AppSelection/Repository/Models/Blocklist.swift` exists (Read-verified + git-tracked in `e8000a4`).
- [x] `DeluluDetox/Sources/Features/AppSelection/Repository/BlocklistRepository.swift` exists (Read-verified + git-tracked in `785390d`).
- [x] `DeluluDetoxTests/Features/AppSelection/BlocklistTests.swift` exists (git-tracked in `e8000a4`).
- [x] `DeluluDetoxTests/Features/AppSelection/BlocklistRepositoryTests.swift` exists (git-tracked in `785390d`).
- [x] Commit `e8000a4` present in `git log --oneline`.
- [x] Commit `785390d` present in `git log --oneline`.
- [x] Full test suite green on iPhone 17 simulator / iOS 26.3 — 35 tests, 3 device-seeded skips, 0 failures.
- [x] No `import SwiftUI` in `Features/AppSelection/Repository/` tree (clean Architecture layer boundary upheld).
