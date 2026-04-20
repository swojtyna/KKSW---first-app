# Roadmap: DeluluDetox

## Overview

DeluluDetox ships in six phases that build vertically from project scaffold to engagement features. Phase 1 establishes the multi-target Xcode project and onboarding flow. Phase 2 delivers app/category/website selection with token persistence. Phase 3 delivers the core value -- quick sessions that block apps and hold the block. Phase 4 customizes the shield overlay with branding and deep linking. Phase 5 adds recurring scheduled blocks via DeviceActivityMonitor. Phase 6 layers on gamification and notifications to drive retention.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation & Onboarding** - Scaffold multi-target Xcode project and deliver Screen Time authorization flow (completed 2026-04-18)
- [x] **Phase 01.1: Architecture Foundation & DI Migration** (INSERTED) - Feature-first layout + DIContainer before new features land (completed 2026-04-19)
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
- [x] 01-01-PLAN.md -- Scaffold multi-target XcodeGen project with extensions, App Group, SPM deps, design system, and domain layer
- [x] 01-02-PLAN.md -- Implement onboarding flow: ViewModels, Views, app entry point, and unit tests
- [x] 01-03-PLAN.md -- Human verification of onboarding screens and authorization flow

### Phase 01.1: Architecture Foundation & DI Migration (INSERTED)

**Goal**: Przestawić projekt na układ feature-first z `DIContainer` i jasnymi regułami zależności (Repo ↛ Repo, UseCase → UseCase/Repo, VM → tylko UseCase) zanim dołożymy kolejne feature'y.
**Depends on**: Phase 1
**Requirements**: TBD (architectural — no user-facing REQ-IDs; decisions D-01..D-31 in 01.1-CONTEXT.md are the coverage axis)
**Scope**:
  - aktualizacja guide'ów architektury i dependency-injection
  - integracja `DIContainer` + property wrappers z `to_integrate/`
  - refaktor istniejących feature'ów (Onboarding, Home, Denial, Root) do feature-first
  - migracja współdzielonego `ScreenTimeAuthRepository` + UC'ów pod feature-ownera (Onboarding)
  - usunięcie `to_integrate/` i starej ręcznej `DependencyContainer`
**Success Criteria** (what must be TRUE):
  1. `.claude/guides/architecture/GUIDE.md` reflects feature-first layout + DI rules
  2. `DIContainer` + property wrappers from `to_integrate/` are integrated and tested
  3. Onboarding, Home, Denial, Root features are reorganized under a feature-first directory layout
  4. Shared components live under their feature-owner's directory (`Features/Onboarding/Repository/` owns `ScreenTimeAuth*` per D-17; no global `FeatureCommons/` — feature-structure/GUIDE.md rejects it)
  5. `to_integrate/` directory and the old manual `DependencyContainer` are removed from the repo
  6. App still builds and Phase 1 onboarding flow still works end-to-end on simulator
**Plans:** 7/7 plans complete
Plans:
- [x] 01.1-01-PLAN.md — DI core migration (`DeluluDetox/Sources/Core/DependencyInjection/`) + extension baseline snapshot (D-18, D-19, D-30 part a)
- [x] 01.1-02-PLAN.md — Onboarding feature-owner: Repo+UC feature-first migration, Combine `statusPublisher`, `refreshStatus()`, `OnboardingInjection.register` (D-07..D-13, D-17, D-20, D-22)
- [x] 01.1-03-PLAN.md — Onboarding/Denial/Home VM → `@LazyInjected` + feature-first move + DenialInjection/HomeInjection no-op (D-03, D-10, D-15, D-16 transitional)
- [x] 01.1-04-PLAN.md — AppRoot Destination enum + Combine subscription + scenePhase hook; DeluluDetoxApp bootstrap; delete `DependencyContainer.swift` + onAuthorized (D-01, D-02, D-04, D-05, D-11, D-14, D-16 final, D-20, D-23)
- [x] 01.1-05-PLAN.md — Test migration to mirror layout + DIContainer.reset() + 4 mocks in feature-owner (D-27, D-28, D-29)
- [x] 01.1-06-PLAN.md — Navigation guide Wzorzec B section + DI guide Combine publisher example (D-24, D-25)
- [x] 01.1-07-PLAN.md — Cleanup `to_integrate/` + extension regression check (D-30 part b) + human-verify checkpoint (D-23 final)

### Phase 2: App Selection
**Goal**: User can choose which apps, categories, and websites to block, and those selections survive app restarts
**Depends on**: Phase 1
**Requirements**: SEL-01, SEL-02, SEL-03, SEL-04, SEL-05
**Success Criteria** (what must be TRUE):
  1. User can open FamilyActivityPicker and select individual apps to block
  2. User can select app categories and websites in the same picker flow
  3. Selections persist across app launches (stored in App Group)
  4. Records are keyed by app-generated UUID with token as best-effort pointer, surviving token rotation
**Plans:** 7 plans
Plans:
- [x] 02-01-PLAN.md — Wave 0 spikes: validate A1 (token JSON round-trip) + A2 (FamilyActivityPicker in NavigationStack sheet)
- [x] 02-02-PLAN.md — Domain models (Blocklist, TokenRecord, TokenKind) + BlocklistRepository with atomic App Group persistence
- [x] 02-03-PLAN.md — 4 UseCases + AppSelectionInjection + DeluluDetoxApp bootstrap edit + 5 test mocks
- [x] 02-04-PLAN.md — BlockedViewModel + BlockedView (list + swipe + Zmień wybór footer)
- [x] 02-05-PLAN.md — AppRootViewModel reconcile hook on scenePhase .active (SEL-05)
- [x] 02-06-PLAN.md — HomeViewModel Destination enum + HomeView branch + PickerHostView sheet + Polish empty-state copy
- [x] 02-07-PLAN.md — Human-verify on physical iOS 26+ device (full SEL-01..SEL-05 walkthrough)
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
**Plans:** 7 plans
Plans:
- [x] 03-01-PLAN.md — Session domain models (Outcome, Duration, Record, FinalizeMarker, Paths) + SessionRepository with two-file atomic persistence
- [x] 03-02-PLAN.md — SessionEnforcer wrapping ManagedSettings + DeviceActivityCenter (QSN-03 shield + QSN-05 system restrictions + QSN-06 DAS)
- [x] 03-03-PLAN.md — 9 Session UseCases + SessionInjection + DeluluDetoxApp bootstrap + 11 test mocks (atomic Start rollback, compose End/Finalize/SelfHeal/DetectRevocation + MarkSuccessShown/CheckSuccessShown VM-boundary UCs)
- [x] 03-04-PLAN.md — DAM extension intervalDidEnd: clear shared ManagedSettingsStore + write finalize marker + post Darwin notification; project.yml source-share
- [x] 03-05-PLAN.md — SessionStartViewModel + SessionStartView (preset chips QSN-01 + custom wheel QSN-02 + empty-blocklist gate)
- [x] 03-06-PLAN.md — CountdownViewModel + TickClock + SessionSuccessViewModel + HomeView destinations + AppRootViewModel foreground self-heal hook
- [x] 03-07-PLAN.md — Human-verify on physical iOS 26+ device (full QSN-01..QSN-06 walkthrough)
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
**Plans:** 7 plans (5 complete + 2 gap-closure)
Plans:
- [x] 04-01-PLAN.md — Wave 0 spike (extensionContext.open device check) + 3 XCTest scaffolds (ShieldConfigurationBuilder/ShieldActionHandler/HomeViewModel deep-link)
- [x] 04-02-PLAN.md — project.yml URL scheme + source-shares; ShieldConfigurationBuilder + ActiveSessionEnvelope; ShieldConfigurationExtension wired (SHL-01, SHL-02)
- [x] 04-03-PLAN.md — ShieldActionHandler pure decision + ShieldActionExtension wired with extensionContext.open (SHL-03)
- [x] 04-04-PLAN.md — HomeViewModel.handleDeepLink + AppRootView.onOpenURL (SHL-04)
- [x] 04-05-PLAN.md — Human device verification (full SHL-01..SHL-04 walkthrough) — Partial pass: SHL-03 dispatch deferred, SHL-02 unverified
- [x] 04-06-PLAN.md — [gap-closure] Local-push-notification fallback for SHL-03 dispatch (ShieldNotificationDispatcher + UNUserNotificationCenterDelegate + auth request at App launch)
- [x] 04-07-PLAN.md — [gap-closure] SHL-02 fallback copy contract tests (automated guard replacing deferred device check)
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
**Plans:** 8 plans
Plans:
- [x] 05-01-wave0-spike-scaffolds-PLAN.md — Wave 0 physical-device spike (DAS repeats=true) + scheduling feature scaffold (Models/Paths/Injection skeleton) + 11 XCTest scaffolds with XCTSkipIf stubs + 10 mocks + project.yml DAM source-shares
- [x] 05-02-schedule-repository-PLAN.md — ScheduleRepository (App Group atomic JSON) + CreateOrUpdateScheduleUseCase + ConsumeScheduleEventMarkerUseCase (multi-marker timestamp-suffixed — resolves RESEARCH OQ#4) + 12 tests
- [x] 05-03-shield-and-monitoring-repositories-PLAN.md — ScheduleShieldRepository (deluludetox.schedule named store) + ScheduleActivityMonitoringRepository (1 or 2 DAS per cross-midnight split) + Schedule+DeviceActivity extension + 10 tests
- [x] 05-04-usecases-and-di-PLAN.md — ComputeScheduleWindowUseCase (pure) + Sync/Toggle/Observe/SelfHeal UCs + SchedulingInjection body (3 repos .application + 7 UCs .unique) + AppRootViewModel schedule foreground hook + 2 Darwin observers + 19 tests
- [x] 05-05-dam-extension-handlers-PLAN.md (wave 2) — DAM extension intervalDidStart + intervalDidEnd schedule paths with prefix dispatch + weekday filter + multi-marker writes + Darwin posts (SCH-03 core; SCH-04 delivered by Phase 4 shield parity — zero new shield code)
- [x] 05-06-editor-viewmodel-and-view-PLAN.md — ScheduleEditorViewModel (@Observable, draft state, Destination.errorAlert) + ScheduleEditorView (7 day chips + 3 presets + 2 wheel DatePickers + cross-midnight marker + enabled Toggle + Save CTA) + ScheduleDayChip subview + Theme+Scheduling extension + 8 VM tests
- [x] 05-07-list-viewmodel-and-navigation-PLAN.md — ScheduleListViewModel (@Observable, observes publisher, Destination.scheduleEditor + errorAlert) + ScheduleListView (List rows + row Toggle + empty state + navigationDestination to editor) + HomeViewModel.scheduleList destination case + HomeView toolbar button + 5 tests
- [x] 05-08-device-uat-PLAN.md — Human verification on physical iOS 26+ device — 7 scenarios: SCH-01 basic fire, SCH-02 disable, SCH-03 weekday filter, SCH-03 cross-midnight, SCH-04 shield parity, marker consumption, session×schedule coexistence
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
**Plans:** 5 plans
Plans:
- [x] 06-01-PLAN.md — Stats compute core: Stats model + pure ComputeStatsUseCase + 20+ DST-safe XCTests (GAM-01/02)
- [x] 06-02-PLAN.md — Notifications infra: LocalNotificationRepository + NotificationCaptionLibrary + composite AppNotificationDelegate + DeluluDetoxApp rewire (delegate swap + drop launch auth)
- [x] 06-03-PLAN.md — NTF-01: Schedule/Cancel/LazyPrompt UCs + StartSession/EndSession hooks + HomeViewModel D-13 trigger
- [ ] 06-04-PLAN.md — NTF-02: ReconcileScheduleNotificationsUseCase + SyncScheduleWithSystemUseCase hook + AppRootViewModel foreground reconcile (cross-midnight evening-only)
- [ ] 06-05-PLAN.md — Stats presentation: ObserveStatsUseCase + StatsViewModel + HomeStatsCardViewModel + StatsInjection + drop mock data from StatsView & HomeDashboardView + HomeViewModel.Destination.stats
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6
(Phases 4, 5, and 6 all depend on Phase 3 but not on each other)

| Phase | Plans Complete | Status | Completed |
|-------|---------------|--------|-----------|
| 1. Foundation & Onboarding | 3/3 | Complete | 2026-04-18 |
| 01.1. Architecture Foundation & DI Migration | 7/7 | Complete | 2026-04-19 |
| 2. App Selection | 0/? | Not started | - |
| 3. Quick Sessions | 0/7 | Not started | - |
| 4. Shield Customization | 0/? | Not started | - |
| 5. Scheduled Blocking | 0/8 | Not started | - |
| 6. Engagement Layer | 0/? | Not started | - |
