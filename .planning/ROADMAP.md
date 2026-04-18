# Roadmap: DeluluDetox

## Overview

DeluluDetox ships in six phases that build vertically from project scaffold to engagement features. Phase 1 establishes the multi-target Xcode project and onboarding flow. Phase 2 delivers app/category/website selection with token persistence. Phase 3 delivers the core value -- quick sessions that block apps and hold the block. Phase 4 customizes the shield overlay with branding and deep linking. Phase 5 adds recurring scheduled blocks via DeviceActivityMonitor. Phase 6 layers on gamification and notifications to drive retention.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Foundation & Onboarding** - Scaffold multi-target Xcode project and deliver Screen Time authorization flow
- [ ] **Phase 2: App Selection** - User can pick apps, categories, and websites to block with persistent token storage
- [ ] **Phase 3: Quick Sessions** - User can start an instant block that holds until the timer expires (core value)
- [ ] **Phase 4: Shield Customization** - Blocked apps show branded shield with deep link back to main app
- [ ] **Phase 5: Scheduled Blocking** - User can create recurring block schedules that execute automatically
- [ ] **Phase 6: Engagement Layer** - Session stats, streak tracking, and local notifications

## Phase Details

### Phase 1: Foundation & Onboarding
**Goal**: User completes onboarding and grants Screen Time permission, on a working multi-target project scaffold
**Depends on**: Nothing (first phase)
**Requirements**: ONB-01, ONB-02, ONB-03
**Success Criteria** (what must be TRUE):
  1. Xcode project builds and runs on simulator with main app target and all three extension targets (DeviceActivityMonitor, ShieldConfiguration, ShieldAction)
  2. User launches app and sees an explanation screen describing why Screen Time permission is needed
  3. User can tap a button to trigger the system Screen Time authorization prompt (individual mode)
  4. If user denies permission, app shows a fallback screen with a retry option that re-triggers the prompt
  5. App Group container is configured and accessible from all targets
**Plans:** 3 plans
Plans:
- [ ] 01-01-PLAN.md -- Scaffold multi-target XcodeGen project with extensions, App Group, SPM deps, design system, and domain layer
- [ ] 01-02-PLAN.md -- Implement onboarding flow: ViewModels, Views, app entry point, and unit tests
- [ ] 01-03-PLAN.md -- Human verification of onboarding screens and authorization flow

### Phase 2: App Selection
**Goal**: User can choose which apps, categories, and websites to block, and those selections survive app restarts
**Depends on**: Phase 1
**Requirements**: SEL-01, SEL-02, SEL-03, SEL-04, SEL-05
**Success Criteria** (what must be TRUE):
  1. User can open FamilyActivityPicker and select individual apps to block
  2. User can select app categories and websites in the same picker flow
  3. Selections persist across app launches (stored in App Group)
  4. Records are keyed by app-generated UUID with token as best-effort pointer, surviving token rotation
**Plans**: TBD
**UI hint**: yes

### Phase 3: Quick Sessions
**Goal**: User can start an instant block for a chosen duration and the block holds until the timer ends
**Depends on**: Phase 2
**Requirements**: QSN-01, QSN-02, QSN-03, QSN-04, QSN-05, QSN-06
**Success Criteria** (what must be TRUE):
  1. User can start a block session by choosing a preset duration (15, 30, 60, or 90 minutes) or setting a custom time
  2. After starting a session, previously selected apps show a shield overlay and cannot be used
  3. User sees a live countdown timer in the main app showing remaining block time
  4. User cannot trivially cancel the session before the timer expires
  5. Session ends automatically when the timer reaches zero and blocked apps become accessible again
**Plans**: TBD
**UI hint**: yes

### Phase 4: Shield Customization
**Goal**: Blocked apps display a branded shield with actionable deep link to the main app
**Depends on**: Phase 3
**Requirements**: SHL-01, SHL-02, SHL-03, SHL-04
**Success Criteria** (what must be TRUE):
  1. Shield overlay displays custom DeluluDetox branding (colors, icon, motivational text)
  2. Shield shows a sensible fallback design when encountering unknown or unexpected tokens
  3. Shield has a button that deep links to the main app
  4. Main app receives the deep link and navigates to the relevant active session context
**Plans**: TBD
**UI hint**: yes

### Phase 5: Scheduled Blocking
**Goal**: User can create a recurring schedule that automatically blocks apps during specified time windows
**Depends on**: Phase 3
**Requirements**: SCH-01, SCH-02, SCH-03, SCH-04
**Success Criteria** (what must be TRUE):
  1. User can create a schedule by selecting days of the week and a time range
  2. User can enable or disable their schedule with a toggle
  3. When a schedule is active, the DeviceActivityMonitor extension automatically applies blocks during the scheduled window
  4. Shield overlay during scheduled blocks behaves identically to quick session shields
**Plans**: TBD
**UI hint**: yes

### Phase 6: Engagement Layer
**Goal**: User gets feedback on their blocking habits and timely notifications about session events
**Depends on**: Phase 3
**Requirements**: GAM-01, GAM-02, NTF-01, NTF-02
**Success Criteria** (what must be TRUE):
  1. User can see a total count of completed blocking sessions
  2. User can see their current streak (consecutive days with at least one completed session)
  3. User receives a local notification when a quick session ends
  4. User receives a local notification when a scheduled block starts
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6
(Phases 4, 5, and 6 all depend on Phase 3 but not on each other)

| Phase | Plans Complete | Status | Completed |
|-------|---------------|--------|-----------|
| 1. Foundation & Onboarding | 0/3 | Planning complete | - |
| 2. App Selection | 0/? | Not started | - |
| 3. Quick Sessions | 0/? | Not started | - |
| 4. Shield Customization | 0/? | Not started | - |
| 5. Scheduled Blocking | 0/? | Not started | - |
| 6. Engagement Layer | 0/? | Not started | - |
