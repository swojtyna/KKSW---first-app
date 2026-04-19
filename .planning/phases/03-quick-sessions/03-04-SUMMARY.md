---
phase: 03-quick-sessions
plan: "04"
subsystem: Session/Extensions
tags: [DeviceActivityMonitor, extension, ManagedSettings, Darwin, atomic-write, cross-process]
dependency_graph:
  requires:
    - "03-01: SessionFinalizeMarker, SessionPaths (extension-safe models)"
    - "03-02: SessionActivityNames.quickSession (cross-process activity name contract)"
  provides:
    - "Production DeviceActivityMonitorExtension.intervalDidEnd handler"
    - "Cross-process finalize handoff: file (session_finalize_marker.json) + Darwin notification (com.kksw.DeluluDetox.sessionFinalized)"
  affects:
    - "03-05: StartSession UI can rely on DAM auto-clearing shield at plannedEndAt"
    - "03-06: AppRoot foreground hook consumes session_finalize_marker.json (primary) + listens to Darwin notification (fast path)"
tech_stack:
  added:
    - "DeviceActivityMonitor extension now imports ManagedSettings (cross-process shield clear) + CoreFoundation Darwin notifications"
  patterns:
    - "Shared-sources pattern: extension target compiles selected main-app source files via project.yml explicit path entries (XcodeGen GUIDE §shared-sources-between-targets)"
    - "Schema-decouple via local Decodable envelope — extension decodes only `{ id: UUID }` from active_session.json instead of full SessionRecord (keeps FamilyControls out of the 6 MB extension)"
    - "Atomic file write + Darwin notification as cross-process handoff (no shared memory / IPC)"
    - "Activity-name filter gate in intervalDidEnd — future Phase 5 schedule activity will coexist safely"
key_files:
  created:
    - .planning/phases/03-quick-sessions/03-04-SUMMARY.md
  modified:
    - Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift
    - project.yml
decisions:
  - "Decode only {id: UUID} from active_session.json in the extension — avoids compiling SessionRecord (which transitively pulls FamilyControls-adjacent ManagedSettings types) into the DAM target and breaks the 6 MB RAM budget"
  - "Sentinel UUID (all-zeros) on missing active_session.json — main-app FinalizeSessionFromMarkerUseCase will log/discard markers whose sessionId doesn't match the active session; no extension-side crash"
  - "Darwin notification is secondary wake path; primary reconciliation is file check on AppRoot foreground (robust to missed posts when app is suspended)"
metrics:
  duration_minutes: 6
  completed_date: "2026-04-19"
  tasks_completed: 2
  files_created: 0
  files_modified: 2
  tests_added: 0
  test_results: "78 tests, 3 skipped, 0 failures — zero regressions"
requirements:
  - QSN-03
  - QSN-06
---

# Phase 03 Plan 04: DAM intervalDidEnd Handler Summary

**One-liner:** DeviceActivityMonitor extension clears shared ManagedSettingsStore, writes atomic SessionFinalizeMarker to App Group, and posts Darwin notification on session interval end — all while staying lean under the 6 MB RAM ceiling.

## What Was Built

### Task 1: `project.yml` shares 3 Session models with DAM extension (commit `037e3b2`)

Added explicit file paths under `DeviceActivityMonitorExtension.sources`:

```yaml
DeviceActivityMonitorExtension:
  type: app-extension
  platform: iOS
  sources:
    - path: Extensions/DeviceActivityMonitorExtension
    - path: DeluluDetox/Sources/Features/Session/Repository/Models/SessionPaths.swift
    - path: DeluluDetox/Sources/Features/Session/Repository/Models/SessionFinalizeMarker.swift
    - path: DeluluDetox/Sources/Features/Session/Infrastructure/SessionActivityNames.swift
```

Main-app target's `DeluluDetox/Sources` glob still owns the same files for the app binary — each target compiles a separate object file. No duplicate symbols (same pattern as Phase 01.1 Blocklist / BlocklistRepository sharing if applicable).

Verified: `xcodegen generate` → idempotent; `xcodebuild build` → green.

### Task 2: `DeviceActivityMonitorExtension.swift` full `intervalDidEnd` handler (commit `9528c53`)

Replaces the Phase 01 no-op stub with the 4-step canonical DAM handoff:

1. **Activity-name filter gate** — `guard activity == SessionActivityNames.quickSession else { return }`. Ignores future Phase 5 schedule activities.
2. **Clear shared ManagedSettingsStore** (`named: "deluludetox.session"`) — sets `shield.applications`, `shield.applicationCategories`, `shield.webDomains` to nil; sets `dateAndTime.requireAutomaticDateAndTime` + `application.denyAppRemoval` to false. Same named store the main-app `SessionEnforcer` writes to (cross-process identity).
3. **Load active session id** — reads `active_session.json` via `SessionPaths.activeSessionURL()` and decodes only `{ id: UUID }` via a local envelope struct. Sentinel all-zero UUID if file missing.
4. **Write finalize marker** — `SessionFinalizeMarker(sessionId, finalizedAt: Date(), source: .damIntervalDidEnd)` encoded and written atomically with `[.atomic, .completeFileProtectionUntilFirstUserAuthentication]`.
5. **Post Darwin notification** — `com.kksw.DeluluDetox.sessionFinalized` via `CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), ...)`.

Every step logs via `os.Logger` with scalar-only `.public` privacy (UUIDs, counts, activity rawValue — no FamilyActivitySelection contents).

Imports only: `DeviceActivity`, `Foundation`, `ManagedSettings`, `os`. Zero FamilyControls / Combine / SwiftUI — extension stays well under the 6 MB ceiling.

Verified: `xcodebuild build` → green; full `xcodebuild test` → 78 tests, 3 skipped, 0 failures (zero regressions from P01+P02+P03).

## Build & Test Results

### `xcodebuild build` — DeluluDetox scheme

```
ValidateEmbeddedBinary .../PlugIns/DeviceActivityMonitorExtension.appex
ValidateEmbeddedBinary .../PlugIns/ShieldActionExtension.appex
ValidateEmbeddedBinary .../PlugIns/ShieldConfigurationExtension.appex
...
** BUILD SUCCEEDED **
```

DeviceActivityMonitorExtension.appex is embedded in the host DeluluDetox.app — confirms the extension target compiles with the shared Session sources AND is linked by the host.

### `xcodebuild test` — full suite

```
Test Suite 'DeluluDetoxTests.xctest' passed
Executed 78 tests, with 3 tests skipped and 0 failures (0 unexpected) in 0.543 seconds
** TEST SUCCEEDED **
```

Preserves the P03 baseline (78 tests, 3 skipped from the Phase 02 picker presentation spikes). This plan ships no new tests — per `<assumptions>` §7, extensions are not XCTest-unit-testable; behavior is contract-validated via the `SessionFinalizeMarker` Codable round-trip in P01 and will be UAT-validated in P07.

## Acceptance Criteria Grep Audit

### Task 1 — project.yml

| Check | Result |
|-------|--------|
| `SessionPaths.swift` path under DeviceActivityMonitorExtension | PASS (line 65) |
| `SessionFinalizeMarker.swift` path under DeviceActivityMonitorExtension | PASS (line 66) |
| `SessionActivityNames.swift` path under DeviceActivityMonitorExtension | PASS (line 67) |
| `xcodegen generate` succeeds | PASS (idempotent on 2nd run) |
| `xcodebuild build` green | PASS |

### Task 2 — DeviceActivityMonitorExtension.swift

| Token | Status |
|-------|--------|
| `override func intervalDidEnd` | PASS (1 match, line 32) |
| `SessionActivityNames.quickSession` | PASS (line 38 filter gate) |
| `ManagedSettingsStore(named:` | PASS (line 61) |
| `SessionPaths.finalizeMarkerURL` | PASS (line 96) |
| `SessionFinalizeMarker` | PASS (line 97) |
| `CFNotificationCenterGetDarwinNotifyCenter` | PASS (line 113) |
| `com.kksw.DeluluDetox.sessionFinalized` | PASS (line 25) |
| `import FamilyControls` count | **0** (PASS — extension stays lean) |
| `import SwiftUI` count | **0** (PASS) |
| `import Combine` count | **0** (PASS) |
| Phase 01 "TODO" stub body removed | PASS |

## RAM Posture Confirmation

```
$ grep -c "^import FamilyControls$" Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift
0
$ grep -c "^import SwiftUI$" Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift
0
$ grep -c "^import Combine$" Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift
0
```

Extension imports only `DeviceActivity + Foundation + ManagedSettings + os`. CoreFoundation Darwin APIs are transitively available via Foundation — no additional imports required. Well under the 6 MB DAM ceiling (PROJECT hard constraint §8).

## Deviations from Plan

None — plan executed exactly as written. Both tasks landed on first build attempt; no auto-fixes needed. No auth gates. No architectural decisions surfaced.

## Threat Model Mitigations — Applied

| Threat ID | Mitigation | Status |
|-----------|------------|--------|
| T-03-04-01 (partial marker write mid-crash) | `options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]` | Applied |
| T-03-04-02 (extension fails to clear shield) | Double-belt — main-app self-heal in P06 will re-check on foreground | Deferred to P06 (correct) |
| T-03-04-03 (extension RAM overrun) | Imports limited to Foundation + DeviceActivity + ManagedSettings + os; `grep -c import FamilyControls` = 0 | Applied |
| T-03-04-04 (no audit trail) | `os.Logger` scalar-only `.public` logs every step; no FamilyActivitySelection content | Applied |
| T-03-04-05 (marker file contains session UUID) | Accepted per plan — UUIDs are opaque IDs, not PII | Accepted |
| T-03-04-06 (wrong activity name triggers clear) | `guard activity == SessionActivityNames.quickSession else { return }` | Applied |
| T-03-04-07 (attacker-spoofs marker) | Accepted per plan — App Group sandbox + main-app sessionId equality check | Accepted |

## Known Stubs

None. The extension writes real data paths:

- `SessionPaths.activeSessionURL()` — real App Group URL (P01 deliverable)
- `SessionPaths.finalizeMarkerURL()` — real App Group URL (P01 deliverable)
- `SessionFinalizeMarker` — real Codable model (P01 deliverable)
- `ManagedSettingsStore(named: "deluludetox.session")` — real cross-process store (main-app `SessionEnforcer` writes to same name in P02)
- Darwin notification name `com.kksw.DeluluDetox.sessionFinalized` — real cross-process wake signal (P06 will add the listener)

Marker consumption is not stubbed either — `SessionRepository.consumeFinalizeMarker()` already exists from P01, and P06 will wire the `FinalizeSessionFromMarkerUseCase` into `AppRoot.onForeground`.

## Threat Flags

No new network endpoints, auth paths, trust boundaries, or schema changes beyond what the plan's `<threat_model>` covers. Marker file format (T-03-04-05 / P01) unchanged. ManagedSettingsStore name and activity name already registered in P02.

## Commits

| Hash | Scope | Message |
|------|-------|---------|
| `037e3b2` | project.yml | feat(03-04): share Session model sources with DAM extension target |
| `9528c53` | Extensions/DeviceActivityMonitorExtension | feat(03-04): implement DAM intervalDidEnd — clear shield + write marker + Darwin notify |

## Next Steps

- **P05 (wave 3):** Session Start UI — duration chips (15/30/60/90 min), Start button triggers `StartSessionUseCase` (P03 deliverable).
- **P06 (wave 4):** Countdown View + AppRoot foreground hook — listens for Darwin notification AND polls `SessionPaths.finalizeMarkerURL()` on foreground, calling `FinalizeSessionFromMarkerUseCase` (which consumes the marker this extension writes).
- **P07 (wave 5):** End-to-end UAT on device — verifies that `intervalDidEnd` actually fires on a real 5-minute session end (DAM does not fire reliably on simulator; requires device + real wall-clock).

## Self-Check: PASSED

- `Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` — FOUND (102 lines, 4-step handler).
- `project.yml` — FOUND (3 shared source paths added under DeviceActivityMonitorExtension).
- Commit `037e3b2` — FOUND in git log (`feat(03-04): share Session model sources with DAM extension target`).
- Commit `9528c53` — FOUND in git log (`feat(03-04): implement DAM intervalDidEnd ...`).
- `xcodegen generate` — idempotent (2nd run produces no diff).
- `xcodebuild build` — green on DeluluDetox scheme.
- `xcodebuild test` — 78 tests, 3 skipped, 0 failures.
