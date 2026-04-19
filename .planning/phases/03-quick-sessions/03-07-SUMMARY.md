---
phase: 03-quick-sessions
plan: 07
status: completed
completed: 2026-04-19T20:41:43Z
gap_closure: false
type: checkpoint:human-verify
requirements:
  - QSN-01
  - QSN-02
  - QSN-03
  - QSN-04
  - QSN-05
  - QSN-06
key-files:
  created: []
  modified: []
---

# 03-07 — Human Verification Checkpoint

## Outcome

User approved after a gap fix cycle. The Phase 3 quick-session flow was exercised on a physical iOS 26+ device against acceptance criteria QSN-01..QSN-06.

## Pre-flight test gate

- `xcodebuild test` on iPhone 17 / iOS 26.3.1 simulator: **133 tests, 130 passed, 3 device-seeded skips, 0 failures**.
- Meets the ≥125 test threshold defined in `03-07-PLAN.md` task 1.

## Gap discovered and fixed during UAT

**Gap:** Custom session durations below 15 minutes briefly showed the countdown screen and then closed, leaving no active session on disk.

**Root cause:** `SessionEnforcer.startActivityMonitoring` registers a `DeviceActivitySchedule`. Apple's Screen Time API requires that schedule's interval to be at least 15 minutes. Shorter windows either get rejected or cause the DAM extension to fire `intervalDidEnd` immediately — that cleared the shield and wrote a finalize marker, which the main-app reconcile then treated as a normal end, finalizing the session and nulling `activeSubject`. The HomeViewModel observer dropped the `.countdown` destination, so the user saw the screen "close" a second after tapping Start.

**Fix (commit `2318bbf`):**
- `SessionDuration.minSeconds` raised from `5 * 60` → `15 * 60`.
- Domain comment now documents the Apple constraint.
- `SessionRecordTests` boundary tests updated (15 min accepted, 14m59s rejected).
- `SessionStartViewModel.customDurationSeconds` didSet clamp and `SessionStartView` DatePicker binding already reference `SessionDuration.minSeconds`, so they automatically enforce the new floor with no further changes.

After the fix, the user re-ran the on-device walkthrough and approved.

## Walkthroughs covered

- **A — 15-minute preset happy path** (QSN-01, QSN-03, QSN-04, QSN-06): start from Home toolbar → countdown shows → blocked apps are shielded → session finalizes on its own → success screen appears once.
- **B — Custom duration via wheel picker** (QSN-02): custom duration now correctly rejected below 15 min; valid custom durations (e.g. 16–20 min) start cleanly and run to completion.
- **C — End early** (QSN-05): "Zakończ wcześniej" → confirm dialog → confirming ends with `outcome=cancelled_by_user`; cancel keeps the session running.
- **D — Revocation** (QSN-05): revoke Screen Time access mid-session in Settings → reopening the app finalizes the session with `outcome=broken_by_revoke`.
- **E — Success-once guarantee**: the sarcastic success screen is presented exactly once per completed session via the `MarkSuccessShownUseCase` / `CheckSuccessShownUseCase` UserDefaults boundary.

## Notes

- Custom-duration minimum now matches the shortest QSN-01 preset (15 min). Product copy in `SessionStartView` already directs users to "Wybierz preset albo ustaw własny czas", with the wheel picker silently clamped — no user-facing error required for now.
- All Phase 3 requirements (QSN-01..QSN-06) are exercised end-to-end on hardware.
