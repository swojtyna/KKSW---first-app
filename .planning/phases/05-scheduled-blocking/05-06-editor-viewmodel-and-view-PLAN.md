---
phase: 05
plan: 06
type: execute
wave: 3
depends_on: [05-04]
files_modified:
  - DeluluDetox/Sources/Features/Scheduling/Editor/ViewModel/ScheduleEditorViewModel.swift
  - DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleEditorView.swift
  - DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleDayChip.swift
  - DeluluDetox/Sources/DesignSystem/Theme+Scheduling.swift
  - DeluluDetoxTests/Features/Scheduling/ScheduleEditorViewModelTests.swift
autonomous: true
requirements: [SCH-01, SCH-02]
must_haves:
  truths:
    - "User can create a new schedule by selecting days of the week, a start time, and an end time, then tap Save (SCH-01)"
    - "User can toggle the `enabled` flag in the editor — saving persists it (SCH-02 main entry)"
    - "User can select days via individual 7 chips (Pn..Nd) OR via presets (Dni robocze / Weekend / Codziennie) — presets overwrite current selection (D-09)"
    - "User can set start/end times via two wheel DatePickers (.wheel, .hourAndMinute) — identical pattern to Phase 3 custom duration (D-10)"
    - "Editor shows a subtle 'Cross-midnight' marker when end <= start — no blocking validation (D-10)"
    - "Save calls CreateOrUpdateScheduleUseCase (Plan 02) which triggers sync — DAS registration is automatic"
    - "Save failure shows sarcastic Polish error toast via Destination.errorAlert (D-14)"
  artifacts:
    - path: "DeluluDetox/Sources/Features/Scheduling/Editor/ViewModel/ScheduleEditorViewModel.swift"
      provides: "@Observable @MainActor ViewModel with draft fields (daysOfWeek, startHour/Minute, endHour/Minute, enabled), isCrossMidnight computed, saveTapped() → CreateOrUpdateScheduleUseCase, Destination.errorAlert(String)"
    - path: "DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleEditorView.swift"
      provides: "SwiftUI Form with days-chips row, 3 preset buttons, two .wheel DatePickers, cross-midnight marker, enabled Toggle, Save button, errorAlert"
    - path: "DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleDayChip.swift"
      provides: "DayChip subview — toggle-style chip (Pn..Nd label, filled=selected, outline=deselected), electric violet accent"
    - path: "DeluluDetox/Sources/DesignSystem/Theme+Scheduling.swift"
      provides: "Theme extension — dayChipFilled, dayChipOutline, crossMidnightHintColor (extension on Theme, analogue Phase 3's Theme+Session.swift)"
  key_links:
    - from: "ScheduleEditorViewModel.saveTapped()"
      to: "CreateOrUpdateScheduleUseCase"
      via: "@LazyInjected createOrUpdate + try await createOrUpdate(schedule)"
      pattern: "@LazyInjected private var createOrUpdate: CreateOrUpdateScheduleUseCase"
    - from: "ScheduleEditorView days chips"
      to: "model.daysOfWeek: Set<Int>"
      via: "two-way Binding inverting contains/insert/remove"
      pattern: "model.daysOfWeek.contains|model.daysOfWeek.insert|model.daysOfWeek.remove"
    - from: "ScheduleEditorView preset buttons"
      to: "model.daysOfWeek = [fixed set]"
      via: "direct mutation on button tap"
      pattern: "model.daysOfWeek = \\["
---

<objective>
Ship the schedule editor screen — the full SCH-01 + SCH-02 (main-entry) UI. @Observable ViewModel + SwiftUI View + a DayChip subview + Theme extension. Editor is navigated to from the Schedule List screen (Plan 05-07). This plan does NOT wire list → editor navigation — it creates a self-contained editor that can be previewed and tested in isolation.

Purpose:
- SCH-01: The editor is the primary entry point for creating/editing a recurring schedule. It must support all fields from the D-02 schema (minus `name` which is nil in MVP, and `id`/`blocklistId`/`appVersion` which are auto-assigned).
- SCH-02: The editor shows an enabled Toggle; user flips + saves; `CreateOrUpdateScheduleUseCase` delegates to Sync UC which starts/stops DAS.
- D-09 (7 chips + 3 presets): mirror Apple Clock app repeat picker UX; presets fully overwrite (not toggle).
- D-10 (two wheel pickers + cross-midnight marker): identical UX pattern to Phase 3 SessionStartView custom-duration picker; subtle marker appears below time pickers when wrap detected.

Output:
- `ScheduleEditorViewModel.swift` — 120-ish lines, `@Observable @MainActor`, no SwiftUI import (except `Observation` + `SwiftUINavigation` for `@CasePathable`).
- `ScheduleEditorView.swift` — SwiftUI Form with 4 sections (days + presets, time pickers, enabled toggle + save, cross-midnight hint).
- `ScheduleDayChip.swift` — small reusable SwiftUI view for individual day toggle chips.
- `Theme+Scheduling.swift` — static colors referenced by chips + hint (mirror Phase 3 `Theme+Session.swift`).
- 8 ViewModel unit tests green (from Plan 01 stubs).
- Full suite green.
</objective>

<execution_context>
@/Users/kked/Projects/KKSW---first-app/.claude/get-shit-done/workflows/execute-plan.md
@/Users/kked/Projects/KKSW---first-app/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/05-scheduled-blocking/05-CONTEXT.md
@.planning/phases/05-scheduled-blocking/05-RESEARCH.md
@.planning/phases/05-scheduled-blocking/05-04-SUMMARY.md
@.planning/phases/03-quick-sessions/03-05-SUMMARY.md
@DeluluDetox/Sources/Features/Session/ViewModel/SessionStartViewModel.swift
@DeluluDetox/Sources/Features/Session/View/SessionStartView.swift
@DeluluDetox/Sources/DesignSystem/Theme+Session.swift
@DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule.swift
@DeluluDetox/Sources/Features/Scheduling/Common/UseCase/CreateOrUpdateScheduleUseCase.swift
@DeluluDetox/Sources/Features/AppSelection/UseCase/ObserveBlocklistUseCase.swift

<interfaces>
Final `ScheduleEditorViewModel` shape:
```swift
import Combine
import Foundation
import Observation
import SwiftUINavigation
import os

@MainActor
@Observable
final class ScheduleEditorViewModel: @unchecked Sendable {
    @CasePathable
    enum Destination: Equatable {
        case errorAlert(String)
    }

    var destination: Destination?

    // Draft fields.
    var daysOfWeek: Set<Int>       // 1..7, Calendar.weekday
    var startHour: Int             // 0..23
    var startMinute: Int           // 0..59
    var endHour: Int               // 0..23
    var endMinute: Int             // 0..59
    var enabled: Bool
    private(set) var isSaving: Bool = false

    var isCrossMidnight: Bool {
        let startMin = startHour * 60 + startMinute
        let endMin = endHour * 60 + endMinute
        return endMin <= startMin
    }

    var canSave: Bool { !isSaving && !daysOfWeek.isEmpty }

    private let editingId: UUID?
    private var blocklistId: UUID?   // resolved from ObserveBlocklistUseCase on init
    private let appVersion: String

    @ObservationIgnored @LazyInjected private var createOrUpdate: CreateOrUpdateScheduleUseCase
    @ObservationIgnored @LazyInjected private var observeBlocklist: ObserveBlocklistUseCase
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    @ObservationIgnored private let logger = Logger(subsystem: "com.kksw.DeluluDetox", category: "ScheduleEditor")

    init(existing: Schedule? = nil, appVersion: String = "1.0") {
        self.editingId = existing?.id
        self.appVersion = appVersion
        if let s = existing {
            self.daysOfWeek = Set(s.daysOfWeek)
            self.startHour = s.startHour
            self.startMinute = s.startMinute
            self.endHour = s.endHour
            self.endMinute = s.endMinute
            self.enabled = s.enabled
            self.blocklistId = s.blocklistId
        } else {
            self.daysOfWeek = []
            self.startHour = 9
            self.startMinute = 0
            self.endHour = 17
            self.endMinute = 0
            self.enabled = true
            self.blocklistId = nil
        }
        // Resolve blocklist id (single implicit per MVP).
        observeBlocklist()
            .sink { [weak self] blocklist in
                if self?.blocklistId == nil { self?.blocklistId = blocklist.id }
            }
            .store(in: &cancellables)
    }

    func applyPresetDniRobocze() { daysOfWeek = [2, 3, 4, 5, 6] }       // Mon=2..Fri=6
    func applyPresetWeekend() { daysOfWeek = [7, 1] }                   // Sat=7, Sun=1
    func applyPresetCodziennie() { daysOfWeek = [1, 2, 3, 4, 5, 6, 7] }

    func toggleDay(_ weekday: Int) {
        if daysOfWeek.contains(weekday) { daysOfWeek.remove(weekday) }
        else { daysOfWeek.insert(weekday) }
    }

    /// Returns Bool indicating whether caller (View) should dismiss.
    /// On success: true. On failure: false (errorAlert shown inline).
    @discardableResult
    func saveTapped() async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }

        guard let blocklistId else {
            destination = .errorAlert("Nie mogę zapisać — brak blocklisty. Dodaj najpierw apki do blokady.")
            return false
        }
        let schedule = Schedule(
            id: editingId ?? UUID(),
            name: nil,
            daysOfWeek: Array(daysOfWeek).sorted(),
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            enabled: enabled,
            blocklistId: blocklistId,
            appVersion: appVersion
        )
        do {
            try await createOrUpdate(schedule)
            logger.info("schedule saved id=\(schedule.id.uuidString, privacy: .public) enabled=\(schedule.enabled, privacy: .public)")
            return true
        } catch {
            logger.error("save failed: \(String(describing: error), privacy: .public)")
            destination = .errorAlert("iOS się zbuntował, spróbuj jeszcze raz.")
            return false
        }
    }

    func clearDestination() { destination = nil }
}
```

Existing Phase 3 patterns to mirror:
- `SessionStartViewModel.swift` lines 1-30: `@MainActor @Observable final class ... @unchecked Sendable` + `@CasePathable enum Destination` + `@LazyInjected` properties.
- `Theme+Session.swift`: minimal Theme extension with named static colors.
</interfaces>

<ux_decisions>
- **Day labels (PL):** `("Pn", 2), ("Wt", 3), ("Śr", 4), ("Cz", 5), ("Pt", 6), ("Sb", 7), ("Nd", 1)` — display order Monday-first (PL convention); stored as Calendar.weekday values (1=Sunday..7=Saturday). Mapping in View only.
- **Chip style:** selected = filled electric violet `#7C3AED`, text white; deselected = outlined violet, text violet. Both 40×40 rounded-rectangle corners 12.
- **Preset buttons:** three horizontally-arranged `Button` below the chips row with `.buttonStyle(.bordered)`. Labels "Dni robocze", "Weekend", "Codziennie".
- **Time pickers:** `DatePicker("Od", ...)` + `DatePicker("Do", ...)` with `.datePickerStyle(.wheel)` and `displayedComponents: .hourAndMinute`. Bind to a helper `Date` via computed get/set that reads hour/minute off the model.
- **Cross-midnight marker:** below time pickers, a small `Label("Cross-midnight — nocna zmiana, co?", systemImage: "moon.zzz")` with `.font(.caption)` `.foregroundStyle(.secondary)`. Shown only when `model.isCrossMidnight == true`.
- **Enabled toggle:** `Toggle("Harmonogram aktywny", isOn: $model.enabled)`.
- **Save button:** in `.safeAreaInset(.bottom)` — primary violet button "Zapisz" / "Zapisywanie…" when `isSaving`; `.disabled(!model.canSave)`.
- **Error alert:** `.alert("Błąd", isPresented: ...)` driven by `destination.errorAlert` case. "OK" button dismisses.
- **Top navigation:** `.navigationTitle("Harmonogram")` — list view pushes this screen via navigationDestination (Plan 07).
- **Empty days-of-week edge case:** save is disabled until ≥ 1 day is selected. `canSave` gates the button.
</ux_decisions>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: ScheduleEditorViewModel + 8 tests green</name>
  <files>
    DeluluDetox/Sources/Features/Scheduling/Editor/ViewModel/ScheduleEditorViewModel.swift,
    DeluluDetoxTests/Features/Scheduling/ScheduleEditorViewModelTests.swift
  </files>
  <read_first>
    - DeluluDetox/Sources/Features/Session/ViewModel/SessionStartViewModel.swift (analogue — @MainActor @Observable ViewModel pattern, @LazyInjected properties, Destination.errorAlert case, no SwiftUI import)
    - DeluluDetoxTests/Features/Session/SessionStartViewModelTests.swift (analogue — @MainActor test class with DIContainer reset + mock registration in setUp + tearDown)
    - DeluluDetox/Sources/Features/Scheduling/Common/UseCase/CreateOrUpdateScheduleUseCase.swift (consumed — method signature `callAsFunction(_ schedule: Schedule) async throws`)
    - DeluluDetox/Sources/Features/AppSelection/UseCase/ObserveBlocklistUseCase.swift (consumed — subscribes to blocklist publisher for blocklistId resolution)
    - DeluluDetox/Sources/Features/Scheduling/Common/Repository/Models/Schedule.swift (construct instances per D-02)
    - .planning/phases/05-scheduled-blocking/05-CONTEXT.md §D-09, §D-10, §D-11, §D-12 (UX contract)
  </read_first>
  <behavior>
    1. RED — Turn 8 XCTSkipIf stubs in ScheduleEditorViewModelTests into real assertions. Use `setUp` to reset DIContainer + register mocks; `tearDown` to reset.

       Test file structure (header + setUp/tearDown + 8 methods):
       ```swift
       import Combine
       import XCTest
       @testable import DeluluDetox

       @MainActor
       final class ScheduleEditorViewModelTests: XCTestCase {
           var mockCreateOrUpdate: MockCreateOrUpdateScheduleUseCase!
           var mockObserveBlocklist: MockObserveBlocklistUseCase!

           override func setUp() async throws {
               mockCreateOrUpdate = MockCreateOrUpdateScheduleUseCase()
               mockObserveBlocklist = MockObserveBlocklistUseCase()
               // Seed a default blocklist so VM can resolve blocklistId on init.
               mockObserveBlocklist.blocklistSubject.send(Blocklist.empty(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!))

               DIContainer.shared.reset()
               DIContainer.shared.register(CreateOrUpdateScheduleUseCase.self, scope: .unique) { _ in self.mockCreateOrUpdate }
               DIContainer.shared.register(ObserveBlocklistUseCase.self, scope: .unique) { _ in self.mockObserveBlocklist }
           }

           override func tearDown() async throws {
               DIContainer.shared.reset()
           }

           // ... 8 test methods
       }
       ```

       Tests:
       - `testInitialStateHasNoDaysAndDefault09To17Enabled` — construct ViewModel with existing=nil. Assert `vm.daysOfWeek.isEmpty`, `vm.startHour==9`, `vm.startMinute==0`, `vm.endHour==17`, `vm.endMinute==0`, `vm.enabled==true`, `vm.destination==nil`.
       - `testInitFromExistingSeedsAllFields` — construct ViewModel with existing Schedule(daysOfWeek:[2,3,4], startHour:22, startMinute:30, endHour:6, endMinute:0, enabled:false, ...). Assert all fields match.
       - `testPresetDniRoboczeSetsMonToFriWeekdays` — call `vm.applyPresetDniRobocze()`. Assert `vm.daysOfWeek == [2,3,4,5,6]`.
       - `testPresetWeekendSetsSatAndSun` — call `applyPresetWeekend()`. Assert `vm.daysOfWeek == [7, 1]`.
       - `testPresetCodziennieSetsAllSeven` — call `applyPresetCodziennie()`. Assert `vm.daysOfWeek == [1,2,3,4,5,6,7]`.
       - `testCrossMidnightDetectionWhenEndLessThanStart` — set startHour=22 startMinute=0 endHour=6 endMinute=0. Assert `vm.isCrossMidnight == true`. Also verify startHour=9 endHour=17 → `isCrossMidnight == false`.
       - `testSaveTappedCallsCreateOrUpdateUseCase` — populate vm.daysOfWeek=[2,3,4,5,6], setSave. Await `vm.saveTapped()`. Assert `mockCreateOrUpdate.callCount == 1 && mockCreateOrUpdate.lastSchedule?.daysOfWeek == [2,3,4,5,6] && mockCreateOrUpdate.lastSchedule?.blocklistId == UUID(uuidString: "11111111-1111-1111-1111-111111111111")` + return value `true`. destination == nil.
       - `testSaveTappedFailureSetsErrorAlertDestination` — `mockCreateOrUpdate.stubbedError = NSError(domain:"test", code:1)`. vm.daysOfWeek = [1]. Await `vm.saveTapped()`. Assert `mockCreateOrUpdate.callCount == 1`, return false, `if case .errorAlert(let msg) = vm.destination { XCTAssertEqual(msg, "iOS się zbuntował, spróbuj jeszcze raz.") } else { XCTFail() }`.

       MockCreateOrUpdateScheduleUseCase needs a `lastSchedule: Schedule?` capture — Plan 01's scaffold is minimal; extend here if missing. MockObserveBlocklistUseCase is a Phase 2 mock already present — re-use or create locally if absent.

    2. GREEN — Create ScheduleEditorViewModel.swift per `<interfaces>`. Ensure:
       - No `import SwiftUI`.
       - `@CasePathable enum Destination: Equatable { case errorAlert(String) }`.
       - `@Observable` on class.
       - `@LazyInjected` both UCs.
       - Combine subscription to `observeBlocklist()` resolves `blocklistId` (when nil).
       - `saveTapped` returns Bool (true=dismiss signal for View).

    3. REFACTOR — extract preset sets to constants if clutter:
       ```swift
       private static let workdayWeekdays: Set<Int> = [2, 3, 4, 5, 6]
       private static let weekendWeekdays: Set<Int> = [7, 1]
       private static let allWeekdays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
       ```

    4. `mcp__XcodeBuildMCP__test_sim` scoped to ScheduleEditorViewModelTests: 8 passed, 0 failed.

    Commit: `feat(05-06): ship ScheduleEditorViewModel + 8 tests`.
  </behavior>
  <action>
    See `<behavior>`. Concrete identifiers:
    - `final class ScheduleEditorViewModel: @unchecked Sendable` with `@MainActor @Observable`
    - Destination cases: `.errorAlert(String)` (single case for MVP)
    - `@LazyInjected private var createOrUpdate: CreateOrUpdateScheduleUseCase`
    - `@LazyInjected private var observeBlocklist: ObserveBlocklistUseCase`
    - Presets: hardcoded Set<Int> values [2,3,4,5,6] / [7,1] / [1,2,3,4,5,6,7]
    - `saveTapped() async -> Bool` returning true on success, false on failure
    - Error message verbatim: `"iOS się zbuntował, spróbuj jeszcze raz."`
  </action>
  <verify>
    <automated>mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox -only-testing:DeluluDetoxTests/Features/Scheduling/ScheduleEditorViewModelTests — expect 8 passed, 0 failed</automated>
  </verify>
  <acceptance_criteria>
    - `test -f DeluluDetox/Sources/Features/Scheduling/Editor/ViewModel/ScheduleEditorViewModel.swift` exits 0
    - `grep -c "final class ScheduleEditorViewModel" DeluluDetox/Sources/Features/Scheduling/Editor/ViewModel/ScheduleEditorViewModel.swift` == 1
    - `grep -c "@MainActor" DeluluDetox/Sources/Features/Scheduling/Editor/ViewModel/ScheduleEditorViewModel.swift` >= 1
    - `grep -c "@Observable" DeluluDetox/Sources/Features/Scheduling/Editor/ViewModel/ScheduleEditorViewModel.swift` == 1
    - `grep -c "@CasePathable" DeluluDetox/Sources/Features/Scheduling/Editor/ViewModel/ScheduleEditorViewModel.swift` == 1
    - `grep -c "case errorAlert(String)" DeluluDetox/Sources/Features/Scheduling/Editor/ViewModel/ScheduleEditorViewModel.swift` == 1
    - `grep -c "^import SwiftUI" DeluluDetox/Sources/Features/Scheduling/Editor/ViewModel/ScheduleEditorViewModel.swift` == 0
    - `grep -c "@LazyInjected private var createOrUpdate: CreateOrUpdateScheduleUseCase" DeluluDetox/Sources/Features/Scheduling/Editor/ViewModel/ScheduleEditorViewModel.swift` == 1
    - `grep -c "@LazyInjected private var observeBlocklist: ObserveBlocklistUseCase" DeluluDetox/Sources/Features/Scheduling/Editor/ViewModel/ScheduleEditorViewModel.swift` == 1
    - `grep -c "applyPresetDniRobocze\|applyPresetWeekend\|applyPresetCodziennie" DeluluDetox/Sources/Features/Scheduling/Editor/ViewModel/ScheduleEditorViewModel.swift` == 3
    - `grep -c "var isCrossMidnight: Bool" DeluluDetox/Sources/Features/Scheduling/Editor/ViewModel/ScheduleEditorViewModel.swift` == 1
    - `grep -c "XCTSkipIf(true" DeluluDetoxTests/Features/Scheduling/ScheduleEditorViewModelTests.swift` == 0
    - `mcp__XcodeBuildMCP__test_sim` scoped: 8 passed, 0 failed, 0 skipped
    - Full suite still green
  </acceptance_criteria>
  <done>
    ScheduleEditorViewModel implements full draft model + save flow. 8 tests green. Mocks (Create/Observe) complete. Committed.
  </done>
</task>

<task type="auto">
  <name>Task 2: ScheduleEditorView + ScheduleDayChip + Theme+Scheduling</name>
  <files>
    DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleEditorView.swift,
    DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleDayChip.swift,
    DeluluDetox/Sources/DesignSystem/Theme+Scheduling.swift
  </files>
  <read_first>
    - DeluluDetox/Sources/Features/Session/View/SessionStartView.swift (analogue — SwiftUI Form layout + wheel DatePicker + safeAreaInset primary CTA + alert with manual Binding<Bool>)
    - DeluluDetox/Sources/DesignSystem/Theme+Session.swift (analogue — Theme extension adding named colors without editing Theme.swift)
    - DeluluDetox/Sources/Features/Scheduling/Editor/ViewModel/ScheduleEditorViewModel.swift (consumed — read model.daysOfWeek / model.startHour / etc.)
    - .planning/phases/05-scheduled-blocking/05-RESEARCH.md §Example 5 (canonical ScheduleEditorView SwiftUI body — day chips + presets + time pickers + cross-midnight marker + Toggle + Save)
    - .planning/phases/05-scheduled-blocking/05-CONTEXT.md §D-09, §D-10, §D-11, §D-12 (UX contract)
  </read_first>
  <action>
    Create 3 SwiftUI files. Exact bodies:

    **1. `Theme+Scheduling.swift`:**
    ```swift
    import SwiftUI

    extension Theme {
        // Day chip colors (Phase 5 Plan 06).
        static var dayChipFilledBackground: Color { Color(red: 0.486, green: 0.227, blue: 0.929) }  // #7C3AED electric violet (matches Theme.accent)
        static var dayChipFilledForeground: Color { .white }
        static var dayChipOutlineForeground: Color { Color(red: 0.486, green: 0.227, blue: 0.929) }
        static var dayChipBackground: Color { Color(.systemGray6) }

        // Cross-midnight hint.
        static var crossMidnightHintColor: Color { .secondary }
    }
    ```

    (If Theme isn't an enum or type — inspect `Theme.swift`. If Theme is an enum with static properties, extend per Phase 3 pattern. If Theme is a struct, same. Copy whatever `Theme+Session.swift` does.)

    **2. `ScheduleDayChip.swift`:**
    ```swift
    import SwiftUI

    /// Single day-of-week toggle chip. Filled = selected, outlined = deselected.
    struct ScheduleDayChip: View {
        let label: String            // "Pn", "Wt", etc.
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 40, height: 40)
                    .background(isSelected ? Theme.dayChipFilledBackground : Theme.dayChipBackground)
                    .foregroundStyle(isSelected ? Theme.dayChipFilledForeground : Theme.dayChipOutlineForeground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.clear : Theme.dayChipOutlineForeground, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
        }
    }
    ```

    **3. `ScheduleEditorView.swift`:**
    ```swift
    import SwiftUI
    import SwiftUINavigation

    struct ScheduleEditorView: View {
        @Bindable var model: ScheduleEditorViewModel
        /// Callback invoked when save succeeds — parent dismisses.
        var onSaved: () -> Void = {}

        // Display order Monday-first (PL); Calendar.weekday values.
        private static let displayOrder: [(label: String, weekday: Int)] = [
            ("Pn", 2), ("Wt", 3), ("Śr", 4), ("Cz", 5), ("Pt", 6), ("Sb", 7), ("Nd", 1)
        ]

        var body: some View {
            Form {
                daysSection
                timeSection
                activitySection
            }
            .navigationTitle("Harmonogram")
            .safeAreaInset(edge: .bottom) { saveButton }
            .alert(
                "Błąd",
                isPresented: errorAlertPresented,
                presenting: errorAlertMessage
            ) { _ in
                Button("OK") { model.clearDestination() }
            } message: { msg in
                Text(msg)
            }
        }

        // MARK: sections

        @ViewBuilder
        private var daysSection: some View {
            Section("Dni tygodnia") {
                HStack(spacing: 8) {
                    ForEach(Self.displayOrder, id: \.weekday) { item in
                        ScheduleDayChip(
                            label: item.label,
                            isSelected: model.daysOfWeek.contains(item.weekday),
                            action: { model.toggleDay(item.weekday) }
                        )
                    }
                }
                .padding(.vertical, 4)

                HStack(spacing: 12) {
                    Button("Dni robocze") { model.applyPresetDniRobocze() }.buttonStyle(.bordered)
                    Button("Weekend") { model.applyPresetWeekend() }.buttonStyle(.bordered)
                    Button("Codziennie") { model.applyPresetCodziennie() }.buttonStyle(.bordered)
                }
            }
        }

        @ViewBuilder
        private var timeSection: some View {
            Section("Przedział czasu") {
                DatePicker("Od", selection: startBinding, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                DatePicker("Do", selection: endBinding, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)

                if model.isCrossMidnight {
                    Label("Cross-midnight — nocna zmiana, co?", systemImage: "moon.zzz")
                        .font(.caption)
                        .foregroundStyle(Theme.crossMidnightHintColor)
                }
            }
        }

        @ViewBuilder
        private var activitySection: some View {
            Section {
                Toggle("Harmonogram aktywny", isOn: $model.enabled)
            }
        }

        @ViewBuilder
        private var saveButton: some View {
            Button {
                Task {
                    let didSave = await model.saveTapped()
                    if didSave { onSaved() }
                }
            } label: {
                Text(model.isSaving ? "Zapisywanie…" : "Zapisz")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.dayChipFilledBackground)
            .disabled(!model.canSave)
            .padding()
            .background(.regularMaterial)
        }

        // MARK: bindings

        private var startBinding: Binding<Date> {
            Binding(
                get: {
                    var comp = DateComponents()
                    comp.hour = model.startHour
                    comp.minute = model.startMinute
                    return Calendar.current.date(from: comp) ?? Date()
                },
                set: { new in
                    let comp = Calendar.current.dateComponents([.hour, .minute], from: new)
                    model.startHour = comp.hour ?? 0
                    model.startMinute = comp.minute ?? 0
                }
            )
        }

        private var endBinding: Binding<Date> {
            Binding(
                get: {
                    var comp = DateComponents()
                    comp.hour = model.endHour
                    comp.minute = model.endMinute
                    return Calendar.current.date(from: comp) ?? Date()
                },
                set: { new in
                    let comp = Calendar.current.dateComponents([.hour, .minute], from: new)
                    model.endHour = comp.hour ?? 0
                    model.endMinute = comp.minute ?? 0
                }
            )
        }

        private var errorAlertPresented: Binding<Bool> {
            Binding(
                get: {
                    if case .errorAlert = model.destination { return true } else { return false }
                },
                set: { if !$0 { model.clearDestination() } }
            )
        }

        private var errorAlertMessage: String? {
            if case .errorAlert(let msg) = model.destination { return msg } else { return nil }
        }
    }
    ```

    Build + test: `mcp__XcodeBuildMCP__build_sim` scheme=DeluluDetox (builds with new View files). `mcp__XcodeBuildMCP__test_sim` full suite — 0 failures. No new tests this task (UI layout not unit-tested; Plan 05-08 real-device UAT covers render).

    Commit: `feat(05-06): ship ScheduleEditorView + ScheduleDayChip + Theme extension`.
  </action>
  <verify>
    <automated>mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox destination={iPhone 17} — expect 0 failures; full build green (View files compile)</automated>
  </verify>
  <acceptance_criteria>
    - `test -f DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleEditorView.swift` exits 0
    - `test -f DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleDayChip.swift` exits 0
    - `test -f DeluluDetox/Sources/DesignSystem/Theme+Scheduling.swift` exits 0
    - `grep -c "struct ScheduleEditorView: View" DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleEditorView.swift` == 1
    - `grep -c "@Bindable var model: ScheduleEditorViewModel" DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleEditorView.swift` == 1
    - `grep -c ".datePickerStyle(.wheel)" DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleEditorView.swift` == 2
    - `grep -c "displayedComponents: .hourAndMinute" DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleEditorView.swift` == 2
    - `grep -c "Dni robocze\|Weekend\|Codziennie" DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleEditorView.swift` >= 3
    - `grep -c "Cross-midnight — nocna zmiana, co?" DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleEditorView.swift` == 1
    - `grep -c "Harmonogram aktywny" DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleEditorView.swift` == 1
    - `grep -c "Zapisz" DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleEditorView.swift` >= 1
    - `grep -c "struct ScheduleDayChip: View" DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleDayChip.swift` == 1
    - `grep -c "static var dayChipFilledBackground: Color" DeluluDetox/Sources/DesignSystem/Theme+Scheduling.swift` == 1
    - `mcp__XcodeBuildMCP__build_sim` scheme=DeluluDetox builds green
    - `mcp__XcodeBuildMCP__test_sim` full suite: 0 failures
  </acceptance_criteria>
  <done>
    Editor View + DayChip + Theme extension exist. SwiftUI compiles. Full test suite green. Committed.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| User input / draft model | Hour/minute entered via DatePicker (.wheel) bound to Int fields — wheel constrains to valid ranges so no out-of-range input possible |
| ViewModel / UCase | `@LazyInjected` resolves at first access; must not happen post-DIContainer.reset |
| Save failure / user retry | sarcastic error message presented; state restored to editable on retry |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-05-06-01 | Denial of Service | Double-tap Save spawns two createOrUpdate calls | mitigate | `isSaving` guard + `.disabled(!model.canSave)`; identical to Phase 3 SessionStartViewModel pattern |
| T-05-06-02 | Tampering | Out-of-range hour/minute | mitigate | SwiftUI DatePicker(.wheel, .hourAndMinute) restricts to valid values; VM fields are Ints populated from Calendar.dateComponents |
| T-05-06-03 | Information Disclosure | Logger reveals blocklistId | accept | UUID is opaque identifier, not PII; matches Phase 3 session logging |
| T-05-06-04 | Elevation of Privilege | Missing blocklistId sneaks through | mitigate | `saveTapped` guards on `blocklistId` — returns false with "brak blocklisty" error if nil |
| T-05-06-05 | Repudiation | Save failure not logged | mitigate | `logger.error` on catch block in saveTapped |
| T-05-06-06 | Spoofing | Preset button injected input (N/A — SwiftUI button action) | accept | Button actions are pure in-process mutations; no external input |
</threat_model>

<verification>
1. `mcp__XcodeBuildMCP__test_sim` full suite — 0 failures. Test count grew by ~8 (Plan 06 VM tests).
2. `git log --oneline -2` shows 2 commits from this plan.
3. `grep -c "^import SwiftUI" DeluluDetox/Sources/Features/Scheduling/Editor/ViewModel/ScheduleEditorViewModel.swift` == 0 (VM discipline preserved).
4. `grep -c "struct ScheduleEditorView: View" DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleEditorView.swift` == 1.
5. SwiftUI Preview attachments optional but don't break build.
</verification>

<success_criteria>
- ScheduleEditorViewModel implements full draft model + save flow with error handling.
- ScheduleEditorView renders 7 day chips + 3 preset buttons + 2 wheel time pickers + cross-midnight marker + enabled toggle + save button + error alert.
- ScheduleDayChip subview styled per Phase 1 brand (electric violet).
- Theme+Scheduling extension adds 4 named colors without touching Theme.swift.
- 8 VM unit tests green.
- Full test suite green.
- View compiles with SwiftUI `build_sim`; ready for parent navigation from Plan 07.
</success_criteria>

<output>
After completion, create `.planning/phases/05-scheduled-blocking/05-06-SUMMARY.md`. Note any SwiftUI type-checker timeouts (see Phase 3 06 SUMMARY § "HomeView body split" pattern if body needs decomposition).
</output>
