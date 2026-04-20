---
phase: 05
plan: 08
type: execute
wave: 4
depends_on: [05-04, 05-05, 05-06, 05-07]
files_modified:
  - .planning/phases/05-scheduled-blocking/05-UAT.md
autonomous: false
requirements: [SCH-01, SCH-02, SCH-03, SCH-04]
must_haves:
  truths:
    - "On a physical iOS 26+ device with Family Controls authorization, user can create a schedule via the editor, see it in the list, and DAS fires intervalDidStart at the scheduled time applying the shield (SCH-01 + SCH-03)"
    - "Disabling the schedule via list toggle stops future intervalDidStart fires (SCH-02)"
    - "A cross-midnight schedule (e.g. 22:00-06:00) survives midnight: shield applied at 22:00 evening segment, clears → re-applied at 00:00 morning segment, clears at 06:00 (SCH-03 cross-midnight)"
    - "Shield rendered during a schedule window is visually identical to the shield rendered during a quick session (SCH-04 parity)"
    - "Event markers written by DAM appear in App Group, are consumed by main app on next foreground, and append to schedule_events.json (Plan 05 DAM write + Plan 04 ConsumeScheduleEventMarkerUseCase flow — visible via Console.app log lines)"
  artifacts:
    - path: ".planning/phases/05-scheduled-blocking/05-UAT.md"
      provides: "UAT report with device model + iOS version + per-scenario pass/fail + any issues encountered + final verdict"
  key_links:
    - from: "physical device"
      to: ".planning/phases/05-scheduled-blocking/05-UAT.md"
      via: "human observation + os.Logger lines captured via Console.app"
      pattern: "## Scenario"
---

<objective>
End-to-end human verification of SCH-01..SCH-04 on a physical iOS 26+ device. Simulator cannot validate:
- DeviceActivitySchedule firing reliability on real wall-clock time.
- Cross-midnight segment handoff (evening segment ends at 23:59:59, morning segment starts at 00:00:00).
- ManagedSettingsStore's cross-process shield enforcement.
- Visual shield parity between quick session and schedule.

Purpose: This is the ONLY plan in Phase 5 that delivers definitive confidence on SCH-03. Unit tests cover all in-process logic; UAT covers iOS system behavior that unit tests cannot reach.

Output:
- `.planning/phases/05-scheduled-blocking/05-UAT.md` — structured report with 7 scenarios, each with exact test steps + observed outcome + pass/fail + screenshots (optional) + console log excerpts.
- Final verdict: PASS (all 4 requirements validated) / PARTIAL-PASS (some pass, flag gaps for gap-closure plan) / FAIL (fundamental issue — halt phase closure, surface to user).

No production code changes. Only the UAT document is committed.
</objective>

<execution_context>
@/Users/kked/Projects/KKSW---first-app/.claude/get-shit-done/workflows/execute-plan.md
@/Users/kked/Projects/KKSW---first-app/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/05-scheduled-blocking/05-CONTEXT.md
@.planning/phases/05-scheduled-blocking/05-RESEARCH.md
@.planning/phases/05-scheduled-blocking/05-VALIDATION.md
@.planning/phases/05-scheduled-blocking/05-DISCUSSION-LOG.md
@.planning/phases/05-scheduled-blocking/05-01-SUMMARY.md
@.planning/phases/05-scheduled-blocking/05-02-SUMMARY.md
@.planning/phases/05-scheduled-blocking/05-03-SUMMARY.md
@.planning/phases/05-scheduled-blocking/05-04-SUMMARY.md
@.planning/phases/05-scheduled-blocking/05-05-SUMMARY.md
@.planning/phases/05-scheduled-blocking/05-06-SUMMARY.md
@.planning/phases/05-scheduled-blocking/05-07-SUMMARY.md
@.planning/phases/03-quick-sessions/03-07-SUMMARY.md
@.planning/phases/04-shield-customization/04-05-SUMMARY.md
</context>

<tasks>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 1: Physical device UAT — SCH-01..SCH-04 + cross-midnight + shield parity + marker consumption</name>
  <what-built>
    All of Phase 5's Phase 1-7 code is merged. The app installs on a physical iOS 26+ device via XcodeBuildMCP device workflow (`build_run_device_proj` or manual Xcode→Run on device). Family Controls authorization must be granted (from Phase 1 onboarding, re-authorize if device is fresh). A blocklist must exist with at least one blockable app (Safari is ideal — always available).

    Human walks through 7 scenarios capturing pass/fail per SCH-* requirement. Console.app is attached to the device and filtered by subsystem `com.kksw.DeluluDetox` — log lines are the evidence for marker writes + Darwin notifications + shield apply/clear.
  </what-built>
  <how-to-verify>
    **Pre-flight (5 min):**
    1. Physical iPhone running iOS 26.0+ attached via USB.
    2. Xcode or XcodeBuildMCP configured for device workflow (see `.claude/guides/xcodebuild-mcp/GUIDE.md` §device workflows).
    3. Build + install DeluluDetox on device (use XcodeBuildMCP `build_run_device_proj` if available; else manual Xcode run).
    4. Family Controls authorization: if onboarding re-triggers, complete it and allow Screen Time.
    5. Blocklist: tap "Wybierz apki" on Home, pick Safari (and optionally 1-2 social apps). Confirm blocklist non-empty.
    6. Console.app: connect to device, filter subsystem contains `com.kksw.DeluluDetox`. Keep window visible.
    7. Device clock: use automatic date/time (Settings → General → Date & Time → Set Automatically = ON). Schedule clock-skew defense depends on this.

    Then execute 7 scenarios, recording outcomes in `.planning/phases/05-scheduled-blocking/05-UAT.md`:

    ---

    **Scenario 1: SCH-01 — Create a 2-minute test schedule starting in the near future**

    Steps:
    1. From Home screen, tap the `calendar` toolbar button → Schedule List → empty state → "Stwórz harmonogram".
    2. In the editor:
       - Tap TODAY's day-of-week chip (e.g. Wednesday → "Śr").
       - Set start time to now+3 minutes (wheel picker).
       - Set end time to now+5 minutes (2-minute window).
       - Enabled toggle = ON.
       - Tap "Zapisz".
    3. Editor dismisses, List shows the row: "Śr | HH:MM – HH:MM".
    4. Attempt to open Safari NOW — it opens normally (schedule not yet fired).
    5. Wait until now+3 minutes. Watch Console.app.
    6. At schedule start time: expect log line from `com.kksw.DeluluDetox.DeviceActivityMonitorExtension` subsystem category "Monitor" containing `intervalDidStart` and `schedule applied id=<uuid>` with `apps=<N>`.
    7. Attempt to open Safari — shield appears (branded violet).
    8. Wait until now+5 minutes. At schedule end: expect log line `schedule cleared id=<uuid>` + Darwin post for `scheduleEnded`.
    9. Attempt to open Safari — opens normally (shield cleared).

    Record: PASS / FAIL + observed fire time vs scheduled time delta (should be < 60s).

    ---

    **Scenario 2: SCH-02 — Toggle disable stops future fires**

    Steps:
    1. Create another 2-minute test schedule (same as Scenario 1, but start time = now+5 minutes).
    2. In List: row's toggle = ON.
    3. Wait 1 minute. Tap the row's toggle → OFF.
    4. Watch Console.app: expect log line `schedule disabled id=<uuid>` from main app's `SyncScheduleWithSystemUseCase` category.
    5. Wait until the original start time (now+5 min). NO `intervalDidStart` log line for this schedule should appear.
    6. Safari remains openable throughout.

    Record: PASS / FAIL.

    ---

    **Scenario 3: SCH-03 — Weekday filter fires correctly**

    Steps:
    1. Create a schedule with start=now+2min, end=now+4min, days=[TODAY's weekday ONLY].
    2. Wait for fire. Shield applies. PASS baseline.
    3. Edit that schedule to days=[TOMORROW's weekday] (uncheck today, check tomorrow). Save.
    4. The edit triggers `SyncScheduleWithSystemUseCase` — it stops+restarts DAS. In practice, the running DAS continues; verify intervalDidEnd eventually fires at end time; shield clears. A NEW intervalDidStart should NOT fire today (weekday filter in DAM skips).

    Alternative simpler test: create a schedule for day-X-only where X is NOT today. Wait past the start time. NO `intervalDidStart` triggering a shield apply should happen. Log line `schedule ... weekday ... NOT in days ...` appears if the DAS fires anyway (Wave 0 Outcome A path) but is filtered by weekday. If Wave 0 Outcome B/C (non-repeating), the DAS shouldn't fire at all on day-X since it was registered for day-X.

    Record: PASS / FAIL + which path taken (Outcome A weekday-filter or Outcome B/C non-fire).

    ---

    **Scenario 4: SCH-03 cross-midnight survival (THE HARD ONE)**

    Steps:
    1. Set a schedule with start=22:00 end=06:00 days=[TOMORROW's weekday] (so user can wait until 22:00 tonight).
    2. Option A (fast): fake the test by setting start=(current time +2min) end=(current time+2min+2min across a 23:59→00:00 boundary). Impractical unless near midnight.
    3. Option B (slow, correct): wait until 22:00 tonight. Observe Console at 22:00 → `schedule applied` for `.evening` segment. Attempt Safari → blocked.
    4. At 23:59:59 → `intervalDidEnd` for `.evening` → `schedule cleared` log. BUT at 00:00:00 → `intervalDidStart` for `.morning` segment → `schedule applied` again.
    5. Because the shield was cleared at 23:59:59 and re-applied at 00:00, there's a ~1-second window where Safari could open; observe Console.app for two marker writes (`schedule_event_marker_*.json` files) — both should be present until foreground consumption.
    6. At 06:00 → `intervalDidEnd` for `.morning` → `schedule cleared`. Safari openable.
    7. Foreground the app. Observe: `consumeScheduleMarker` log line from main app + 2+ marker files consumed. `schedule_events.json` now has ≥4 entries (evening-start, evening-end, morning-start, morning-end).

    **If Option B not feasible:** simulate by programmatically triggering the DAM methods via a debug hook (add a temporary button in HomeView if necessary that calls `DeviceActivityCenter.startMonitoring` for a 2-minute cross-midnight synthetic schedule near a midnight boundary — RARE, only if user explicitly has a midnight test window available). Otherwise, DEFER this scenario to a gap-closure plan with a note "cross-midnight not tested this UAT pass — schedule 22:00-06:00 UAT pending next calendar night".

    Record: PASS / FAIL / DEFERRED.

    ---

    **Scenario 5: SCH-04 — Shield parity between quick session and schedule**

    Steps:
    1. Start a Quick Session (15 min) from Home → Session Start. Observe shield on Safari. Screenshot (mental or photo).
    2. Wait until quick session ends (or end it early via confirmation dialog).
    3. Create a 2-minute test schedule (as Scenario 1). Let it fire. Observe shield on Safari.
    4. Compare visually: same branded violet background, same icon, same copy template ("Serio?" / "Zablokowane"). Cross-schedule shield may show different "remaining minutes" value (reads from active_session.json which is quick-session-specific — for schedules it'd be nil → fallback copy "Zablokowane" per SHL-02 Plan 04-07). Accept either: branded main copy or branded fallback copy. NOT accept: Apple default shield (unbranded).

    Record: PASS / FAIL + note whether schedule shield shows main or fallback copy.

    ---

    **Scenario 6: Marker consumption + Darwin notification fires refresh**

    Steps:
    1. Background the app (swipe to home screen).
    2. Wait for a schedule to fire (from Scenario 1 or a new 2-min schedule).
    3. Foreground the app.
    4. Observe Console.app: expect log lines from main app (`AppRoot` / `ConsumeScheduleEventMarkerUseCase` / `SelfHealSchedulesUseCase` categories) indicating marker consumed + self-heal reconciled.
    5. Navigate to Schedule List — enabled state reflects reality. If the schedule just ended, the row toggle is whatever was saved (typically still ON for recurring schedules).
    6. (Optional advanced) Peek at App Group container via Xcode → Window → Devices and Simulators → Installed Apps → DeluluDetox → Download Container. Confirm `schedule_events.json` exists with events; no stale `schedule_event_marker_*.json` files.

    Record: PASS / FAIL.

    ---

    **Scenario 7: Session × schedule coexistence (D-07)**

    Steps:
    1. Create a schedule for now+2min to now+7min, enabled.
    2. Start a quick session (5 min) NOW. Shield appears on Safari.
    3. At now+2min: schedule also fires. Shield remains (union of session + schedule stores). Log lines show both stores in play.
    4. At now+5min: quick session ends (intervalDidEnd on quickSession). `deluludetox.session` store cleared. Schedule store still active. Shield REMAINS on Safari.
    5. At now+7min: schedule ends. `deluludetox.schedule` cleared. Safari openable.

    Record: PASS / FAIL.

    ---

    **Recording format in 05-UAT.md:**

    ```markdown
    # Phase 5 UAT — YYYY-MM-DD

    **Device:** iPhone 14 Pro / iPhone 15 / ... (model + storage)
    **iOS version:** 26.2 / 26.3.1 / ...
    **App build:** DeluluDetox <commit-sha>
    **Wave 0 spike verdict:** Outcome A (from 05-DISCUSSION-LOG.md)
    **Tester:** <name>

    ## Pre-flight
    - [ ] Family Controls authorization granted
    - [ ] Blocklist contains Safari + N apps
    - [ ] Console.app filtered to com.kksw.DeluluDetox subsystem
    - [ ] Device clock auto-set

    ## Scenario 1: SCH-01 + SCH-03 basic fire
    **Result:** PASS / FAIL
    **Fire-time delta:** <observed start> - <scheduled start> = Xs
    **Evidence:** Console excerpt (paste 3-5 lines)
    **Issues:** <none / details>

    ## Scenario 2: SCH-02 disable
    **Result:** ...

    (... continue for scenarios 3-7 ...)

    ## Final Verdict
    - [ ] All 7 scenarios PASS → SCH-01, SCH-02, SCH-03, SCH-04 validated → Phase 5 COMPLETE
    - [ ] Scenarios X..Y DEFERRED (explicit rationale — e.g. cross-midnight not testable today)
    - [ ] Scenarios X..Y FAILED — gap-closure Plan 05-09 required for: <list>

    ## Console log excerpts (optional appendix)
    ```

    Commit ONLY the `05-UAT.md` changes: `test(05-08): complete Phase 5 device UAT — all SCH-* validated` (adjust message per actual verdict).
  </how-to-verify>
  <files>.planning/phases/05-scheduled-blocking/05-UAT.md</files>
  <action>
    This is a human-verify checkpoint — the human executes all 7 scenarios per the `<how-to-verify>` block on a physical iOS 26+ device and records outcomes in `.planning/phases/05-scheduled-blocking/05-UAT.md`. The executor agent MUST NOT attempt to simulate UAT (simulator cannot validate DAS wall-clock firing, cross-midnight handoff, or ManagedSettings shield enforcement). If no physical device is available, MARK this plan as BLOCKED with rationale "physical device unavailable this session" in the UAT document preamble and STOP. Phase 5 cannot be marked Complete until the UAT verdict is recorded.
  </action>
  <verify>
    <automated>grep -c "^## Final Verdict" .planning/phases/05-scheduled-blocking/05-UAT.md</automated>
  </verify>
  <read_first>
    - .planning/phases/05-scheduled-blocking/05-VALIDATION.md §Manual-Only Verifications (recurring DAS reliability, cross-midnight, shield parity, App Group persistence)
    - .planning/phases/05-scheduled-blocking/05-DISCUSSION-LOG.md (Wave 0 Outcome — different UAT interpretation for A vs B/C)
    - .planning/phases/03-quick-sessions/03-07-SUMMARY.md (analogue UAT playbook — Phase 3 real-device UAT structure)
    - .planning/phases/04-shield-customization/04-05-SUMMARY.md (analogue UAT — which scenarios passed, which needed gap-closure)
    - .claude/guides/xcodebuild-mcp/GUIDE.md (device workflow — `build_run_device_proj` or manual device install)
  </read_first>
  <acceptance_criteria>
    - `test -f .planning/phases/05-scheduled-blocking/05-UAT.md` exits 0
    - `grep -c "^## Scenario [1-7]" .planning/phases/05-scheduled-blocking/05-UAT.md` == 7
    - `grep -c "^\*\*Device:\*\*" .planning/phases/05-scheduled-blocking/05-UAT.md` == 1
    - `grep -c "^\*\*iOS version:\*\*" .planning/phases/05-scheduled-blocking/05-UAT.md` == 1
    - `grep -c "^## Final Verdict" .planning/phases/05-scheduled-blocking/05-UAT.md` == 1
    - The Final Verdict section explicitly lists PASS / FAIL / DEFERRED for each of SCH-01, SCH-02, SCH-03, SCH-04
    - If any scenario is FAILED, a note like "gap-closure Plan 05-09 required for: ..." appears with specific acceptance-gap language
    - git commit created with message starting `test(05-08):`
  </acceptance_criteria>
  <resume-signal>
    Type "PASS" / "PARTIAL" / "FAIL" + brief per-requirement summary (e.g. "PASS SCH-01/02/04; DEFERRED SCH-03 cross-midnight — schedule for 22:00-06:00 UAT tomorrow"). If PASS, planner next step is Phase 5 SUMMARY + verification handoff. If PARTIAL/FAIL, orchestrator should invoke `/gsd-plan-phase 05 --gaps` to author closure plans.
  </resume-signal>
  <done>
    05-UAT.md committed with device/iOS info, 7 scenarios recorded, Final Verdict section complete. User has confirmed verdict via resume-signal. If full PASS, phase completion checklist may proceed; if PARTIAL/FAIL, gap-closure planner invocation queued.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Physical device / iOS DeviceActivity subsystem | iOS system is the untrusted runtime — we observe behavior, cannot control it |
| UAT observations / UAT.md record | Human transcription error → false-PASS recorded; mitigated by pasting Console excerpts verbatim |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-05-08-01 | Repudiation | UAT result not reproducible | mitigate | Require Device model + iOS version + commit SHA in UAT.md — any reader can repeat the UAT on their own device |
| T-05-08-02 | Tampering | Test-schedule leftover on device after UAT | accept | UAT creates schedules in App Group file; test-account user can uninstall + reinstall to clear; acceptable dev noise |
| T-05-08-03 | Information Disclosure | Console.app logs captured in UAT.md contain device identifiers | mitigate | Advise tester to paste only category-matching lines; avoid `deviceIdentifierForVendor` or serial numbers (our log lines don't include these per Phase 2/3 logging discipline) |
| T-05-08-04 | DoS | iOS DAM reliability failure causes false-FAIL | mitigate | Wave 0 spike (Plan 01) already caught this risk; if UAT discovers new DAM bug, gap-closure plan 05-09 adds workaround |
| T-05-08-05 | Elevation of Privilege | Tester has unrevoked Screen Time authorization that allows bypass | accept | Screen Time is user-granted; revoking during UAT is explicit user action (not a bug) |
</threat_model>

<verification>
1. `.planning/phases/05-scheduled-blocking/05-UAT.md` exists with required sections.
2. `git log --oneline -1` shows exactly 1 commit with `test(05-08):` prefix.
3. No production code modified by this plan (`git diff HEAD~1 -- DeluluDetox/ Extensions/ project.yml` is empty).
4. Resume signal received from human per task prompt.
</verification>

<success_criteria>
- UAT performed on physical iOS 26+ device with Family Controls authorized.
- 7 scenarios executed and outcomes recorded in `05-UAT.md`.
- Each of SCH-01, SCH-02, SCH-03, SCH-04 explicitly marked PASS / FAIL / DEFERRED.
- Console.app log evidence captured for at least 3 of the 7 scenarios.
- If full PASS: Phase 5 considered feature-complete; planner may proceed to PHASE SUMMARY + update ROADMAP phase 5 status to Complete.
- If PARTIAL/FAIL: specific gaps listed in Final Verdict section; orchestrator should route to `--gaps` closure planning.
</success_criteria>

<output>
After completion, create `.planning/phases/05-scheduled-blocking/05-08-SUMMARY.md` summarizing the UAT verdict — pass/fail per requirement, any deferred scenarios, any gap-closure recommendations.
</output>
