# Requirements: DeluluDetox

**Defined:** 2026-04-18
**Core Value:** User can block chosen apps immediately and the block holds until the timer ends.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Onboarding

- [ ] **ONB-01**: User sees explanation screen describing why Screen Time permission is needed before the request
- [ ] **ONB-02**: User can grant Screen Time permission (individual) via system prompt
- [ ] **ONB-03**: User sees graceful fallback with retry option if permission is denied

### App Selection

- [ ] **SEL-01**: User can select apps to block using FamilyActivityPicker
- [ ] **SEL-02**: User can select app categories to block using FamilyActivityPicker
- [ ] **SEL-03**: User can select websites to block using FamilyActivityPicker
- [ ] **SEL-04**: Selected tokens persist across app launches via App Group
- [ ] **SEL-05**: Token rotation is handled gracefully — records keyed by own UUID, token as best-effort pointer

### Quick Session

- [ ] **QSN-01**: User can start instant block with preset durations (15, 30, 60, 90 min)
- [ ] **QSN-02**: User can set custom block duration via time picker
- [ ] **QSN-03**: Blocked apps show shield overlay during active session
- [ ] **QSN-04**: User sees countdown timer in main app during active session
- [ ] **QSN-05**: User cannot trivially cancel a session mid-block
- [ ] **QSN-06**: Session ends automatically when timer expires

### Schedules

- [ ] **SCH-01**: User can create a recurring schedule (select days of week + time range)
- [ ] **SCH-02**: User can enable/disable their schedule
- [ ] **SCH-03**: Schedule executes via DeviceActivityMonitor extension — apps blocked during scheduled window
- [ ] **SCH-04**: Shield applies during scheduled blocks same as quick sessions

### Shield

- [ ] **SHL-01**: Shield displays custom branding (colors, icon, text)
- [ ] **SHL-02**: Shield shows fallback design for unknown/unexpected tokens
- [ ] **SHL-03**: Shield has action button that deep links to main app
- [ ] **SHL-04**: Main app handles incoming deep link from shield and shows relevant session context

### Gamification

- [ ] **GAM-01**: User sees total count of completed sessions
- [ ] **GAM-02**: User sees current streak (consecutive days with at least one completed session)

### Notifications

- [ ] **NTF-01**: User receives local notification when session ends
- [ ] **NTF-02**: User receives local notification when scheduled block starts

## v2 Requirements

### Deep Focus

- **DFO-01**: User can enable delayed unblock (e.g. 10s breathing exercise before unlock)
- **DFO-02**: User must type a passphrase to break a session early
- **DFO-03**: Session break incurs streak penalty

### Statistics

- **STS-01**: User sees daily/weekly usage stats via DeviceActivityReport extension
- **STS-02**: User sees which blocked apps were attempted most

### Live Activity

- **LAC-01**: User sees session countdown on Lock Screen and Dynamic Island
- **LAC-02**: Live Activity updates in real-time without app foregrounding

### Monetization

- **MON-01**: User can subscribe to premium tier via StoreKit 2
- **MON-02**: Free tier has limited features, premium unlocks full access
- **MON-03**: Paywall shown at natural friction points

### Multi-Schedule

- **MSC-01**: User can create multiple independent schedules
- **MSC-02**: Overlapping schedules merge blocked app sets

## Out of Scope

| Feature | Reason |
|---------|--------|
| Backend / cloud sync | MVP fully on-device, privacy story |
| Parental control / Family Sharing | Explicitly not this product — adult self-control |
| Android / cross-platform | iOS only |
| Accountability partner | Requires backend infrastructure |
| OAuth / social login | No user accounts in MVP |
| Widget | Nice-to-have, not core blocking flow |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| ONB-01 | Phase 1 | Pending |
| ONB-02 | Phase 1 | Pending |
| ONB-03 | Phase 1 | Pending |
| SEL-01 | Phase 2 | Pending |
| SEL-02 | Phase 2 | Pending |
| SEL-03 | Phase 2 | Pending |
| SEL-04 | Phase 2 | Pending |
| SEL-05 | Phase 2 | Pending |
| QSN-01 | Phase 3 | Pending |
| QSN-02 | Phase 3 | Pending |
| QSN-03 | Phase 3 | Pending |
| QSN-04 | Phase 3 | Pending |
| QSN-05 | Phase 3 | Pending |
| QSN-06 | Phase 3 | Pending |
| SHL-01 | Phase 4 | Pending |
| SHL-02 | Phase 4 | Pending |
| SHL-03 | Phase 4 | Pending |
| SHL-04 | Phase 4 | Pending |
| SCH-01 | Phase 5 | Pending |
| SCH-02 | Phase 5 | Pending |
| SCH-03 | Phase 5 | Pending |
| SCH-04 | Phase 5 | Pending |
| GAM-01 | Phase 6 | Pending |
| GAM-02 | Phase 6 | Pending |
| NTF-01 | Phase 6 | Pending |
| NTF-02 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 26 total
- Mapped to phases: 26
- Unmapped: 0

---
*Requirements defined: 2026-04-18*
*Last updated: 2026-04-18 after roadmap creation*
