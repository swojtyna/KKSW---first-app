---
status: partial
phase: 06-engagement-layer
source: [06-VERIFICATION.md]
started: 2026-04-21T00:00:00Z
updated: 2026-04-21T00:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. GAM-01 total count visible on screen
expected: After completing a blocking session, both the Home dashboard card ('UKOŃCZONYCH' quick stat) and the Stats screen footer ('Łącznie ukończonych sesji: N.') show the correct incremented integer from sessions.json history.
result: [pending]

### 2. GAM-02 current streak and longest streak visible
expected: Stats screen top row shows AKTUALNY (current streak) and REKORD (longest streak) cards with correct integers; Home dashboard violet hero card shows current streak; 7-day mini row shows checkmarks for days with at least one completed session, with violet border around today's column.
result: [pending]

### 3. GAM-02 broken-streak branch renders correctly
expected: When currentStreak == 0 && longestStreak >= 3, the Home hero card switches from the violet-flame regular card to the gray-flame SERIA ZERWANA card displaying a shame caption (e.g., 'Straciłeś 12-dniową serię. Imponujące.'). Tap still navigates to the Stats screen.
result: [pending]

### 4. NTF-01 session-end notification fires at scheduled time
expected: Start a 1-minute session with notification permission granted. When the timer naturally expires, iOS delivers a banner with the Polish caption body (e.g., 'Przetrwałeś 1 min bez scrollowania. Świat się nie zawalił.'). In foreground NO banner (silent); in background/lockscreen banner + sound.
result: [pending]

### 5. NTF-01 cancels on early-end and revoke
expected: (a) Start a session, open the shield pre-emptively and tap Cancel before the timer expires → no notification delivers later. (b) Start a session, revoke Screen Time permission (settings toggle) to simulate broken outcome → no notification delivers later.
result: [pending]

### 6. NTF-02 weekday schedule reminder fires at scheduled time
expected: Create an enabled schedule with daysOfWeek including today and startHour 1-2 minutes in the future (wall clock). At the trigger time, iOS delivers a banner with the Polish scheduleStart caption. Foreground banner+sound; background banner+sound.
result: [pending]

### 7. NTF-02 reconcile on save/toggle/foreground
expected: (a) Save a Mon-Fri 09:00 schedule → 5 `schedule.start.{uuid}.{2..6}` pending requests visible in simulator logs. (b) Toggle schedule OFF → all 5 removed. (c) Kill & cold-relaunch app with enabled schedule → foreground reconcile re-populates pending set idempotently.
result: [pending]

### 8. D-13 lazy permission prompt on first completed session
expected: Fresh install (no prior .authorized/.denied state). Complete the first blocking session. Permission prompt appears BEFORE the success screen. Subsequent completed sessions do NOT re-prompt.
result: [pending]

### 9. SHL-03 shield deep-link preserved through AppNotificationDelegate
expected: Trigger a shield notification from ShieldActionExtension (block a tokenized app; tap Open DeluluDetox on the shield). Banner appears with title 'DeluluDetox'; tapping the banner opens the app and routes through ingestShieldDeepLink URL — NOT affected by NTF-01/NTF-02 routing.
result: [pending]

## Summary

total: 9
passed: 0
issues: 0
pending: 9
skipped: 0
blocked: 0

## Gaps
