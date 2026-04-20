---
phase: 05
plan: 07
type: execute
wave: 3
depends_on: [05-04, 05-06]
files_modified:
  - DeluluDetox/Sources/Features/Scheduling/List/ViewModel/ScheduleListViewModel.swift
  - DeluluDetox/Sources/Features/Scheduling/List/View/ScheduleListView.swift
  - DeluluDetox/Sources/Features/Home/ViewModel/HomeViewModel.swift
  - DeluluDetox/Sources/Features/Home/View/HomeView.swift
  - DeluluDetoxTests/Features/Scheduling/ScheduleListViewModelTests.swift
  - DeluluDetoxTests/Features/Home/HomeViewModelTests.swift
autonomous: true
requirements: [SCH-01, SCH-02]
must_haves:
  truths:
    - "User sees a list screen showing the currently-configured schedule (or empty-state prompt) and can tap to edit"
    - "User can toggle the schedule's enabled flag directly from the list row without navigating into the editor (SCH-02 quick-toggle)"
    - "User can create a new schedule from an empty state (SCH-01 entry point)"
    - "HomeView has a navigation entry (toolbar button) leading to the Schedule List screen — integrated into the existing Home nav graph"
    - "List observes ScheduleRepository's publisher — schedule edits/toggles reflect immediately"
  artifacts:
    - path: "DeluluDetox/Sources/Features/Scheduling/List/ViewModel/ScheduleListViewModel.swift"
      provides: "@MainActor @Observable VM with `schedules: [Schedule]` (observed) + Destination.scheduleEditor(ScheduleEditorViewModel) + createTapped/editTapped/toggleSchedule methods"
    - path: "DeluluDetox/Sources/Features/Scheduling/List/View/ScheduleListView.swift"
      provides: "SwiftUI List showing rows per schedule OR empty-state nudge; row has enabled Toggle + tap-to-edit; navigationDestination to ScheduleEditorView"
    - path: "DeluluDetox/Sources/Features/Home/ViewModel/HomeViewModel.swift"
      provides: "New Destination.scheduleList(ScheduleListViewModel) case + scheduleListTapped() trigger"
    - path: "DeluluDetox/Sources/Features/Home/View/HomeView.swift"
      provides: "Toolbar button 'Harmonogram' triggering scheduleListTapped + .navigationDestination(item: destination.scheduleList)"
    - path: "DeluluDetoxTests/Features/Scheduling/ScheduleListViewModelTests.swift"
      provides: "4 tests: observe publisher, edit existing, create new, toggle row"
    - path: "DeluluDetoxTests/Features/Home/HomeViewModelTests.swift"
      provides: "1 new test: scheduleListTapped routes destination to .scheduleList"
  key_links:
    - from: "ScheduleListViewModel"
      to: "ObserveScheduleUseCase → .sink → self.schedules"
      via: "AnyCancellable in init; [weak self] sink closure"
      pattern: "observeSchedule\\(\\).sink"
    - from: "ScheduleListView row Toggle"
      to: "ToggleScheduleUseCase via model.toggleSchedule(id:enabled:)"
      via: "Task + try await toggle"
      pattern: "await model.toggleSchedule"
    - from: "HomeViewModel.Destination"
      to: "ScheduleListViewModel"
      via: "case scheduleList(ScheduleListViewModel) + identity equality"
      pattern: "case scheduleList\\(ScheduleListViewModel\\)"
    - from: "HomeView"
      to: "ScheduleListView"
      via: ".navigationDestination(item: $model.destination.scheduleList)"
      pattern: "navigationDestination\\(item: \\$model.destination.scheduleList"
---

<objective>
Ship the Schedule List screen + Home nav graph entry so users can reach the editor. After this plan, SCH-01 / SCH-02 acceptance flows are UI-complete: Home → Harmonogram → List → (create|edit) → Editor → Save → back to List (updated).

Purpose:
- Navigation integration: Phase 5 editor can't be reached without a nav graph. HomeView adds a toolbar button "Harmonogram" → Schedule List → Editor.
- Quick toggle in list (SCH-02 complement): user can flip enabled directly without full editor dive; consistent with Apple Clock app pattern.
- Empty state: list shows sarcastic empty-state copy when no schedule configured — guides user to create.

Output:
- `ScheduleListViewModel.swift` — @Observable, observes ObserveScheduleUseCase, Destination.scheduleEditor(ScheduleEditorViewModel), createTapped + editTapped + toggleSchedule methods.
- `ScheduleListView.swift` — SwiftUI List rendering rows (or empty state) + navigationDestination to Editor + toolbar create button.
- HomeViewModel + HomeView extended: new `.scheduleList(ScheduleListViewModel)` destination case + toolbar button triggering it.
- 4 new ScheduleListViewModel tests + 1 new HomeViewModel test green.
- Full test suite green, all Phase 1-4 tests preserved.
</objective>

<execution_context>
@/Users/kked/Projects/KKSW---first-app/.claude/get-shit-done/workflows/execute-plan.md
@/Users/kked/Projects/KKSW---first-app/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/05-scheduled-blocking/05-CONTEXT.md
@.planning/phases/05-scheduled-blocking/05-RESEARCH.md
@.planning/phases/05-scheduled-blocking/05-04-SUMMARY.md
@.planning/phases/05-scheduled-blocking/05-06-SUMMARY.md
@.planning/phases/03-quick-sessions/03-06-SUMMARY.md
@DeluluDetox/Sources/Features/Home/ViewModel/HomeViewModel.swift
@DeluluDetox/Sources/Features/Home/View/HomeView.swift
@DeluluDetox/Sources/Features/Session/ViewModel/SessionStartViewModel.swift
@DeluluDetox/Sources/Features/Scheduling/Editor/ViewModel/ScheduleEditorViewModel.swift
@DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ObserveScheduleUseCase.swift
@DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ToggleScheduleUseCase.swift

<interfaces>
Final `ScheduleListViewModel`:
```swift
@MainActor
@Observable
final class ScheduleListViewModel: @unchecked Sendable {
    @CasePathable
    enum Destination: Equatable {
        case scheduleEditor(ScheduleEditorViewModel)
        case errorAlert(String)

        static func == (lhs: Destination, rhs: Destination) -> Bool {
            switch (lhs, rhs) {
            case (.scheduleEditor(let a), .scheduleEditor(let b)): return a === b
            case (.errorAlert(let a), .errorAlert(let b)): return a == b
            default: return false
            }
        }
    }

    var destination: Destination?
    private(set) var schedules: [Schedule] = []

    @ObservationIgnored @LazyInjected private var observeSchedule: ObserveScheduleUseCase
    @ObservationIgnored @LazyInjected private var toggleScheduleUC: ToggleScheduleUseCase
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    @ObservationIgnored private let logger = Logger(subsystem: "com.kksw.DeluluDetox", category: "ScheduleList")

    init() {
        observeSchedule()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in self?.schedules = list }
            .store(in: &cancellables)
    }

    func createTapped() {
        destination = .scheduleEditor(ScheduleEditorViewModel(existing: nil))
    }

    func editTapped(_ schedule: Schedule) {
        destination = .scheduleEditor(ScheduleEditorViewModel(existing: schedule))
    }

    func toggleSchedule(scheduleId: UUID, enabled: Bool) async {
        do {
            try await toggleScheduleUC(scheduleId: scheduleId, enabled: enabled)
            logger.info("schedule toggled id=\(scheduleId.uuidString, privacy: .public) enabled=\(enabled, privacy: .public)")
        } catch {
            logger.error("toggle failed: \(String(describing: error), privacy: .public)")
            destination = .errorAlert("Nie udało się przełączyć — kliknij jeszcze raz.")
        }
    }

    func clearDestination() { destination = nil }
}
```

HomeViewModel existing Destination enum (extend):
```swift
// Before (from Phase 3 Plan 06):
enum Destination: Equatable {
    case picker(PickerSession)
    case errorAlert(String)
    case sessionStart(SessionStartViewModel)
    case countdown(CountdownViewModel)
    case sessionSuccess(SessionSuccessViewModel)
    ...
}

// After (Plan 05-07 adds ONE case):
case scheduleList(ScheduleListViewModel)
```
Also add identity equality in the existing `static func ==` switch for `.scheduleList(let a), .scheduleList(let b): return a === b`.

HomeView existing toolbar (extend — Plan 3 Plan 6 added `play.circle.fill` start-session button):
```swift
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        Button(action: { model.scheduleListTapped() }) {
            Image(systemName: "calendar")
        }
        .accessibilityLabel("Harmonogram")
    }
    ToolbarItem(placement: .topBarTrailing) {
        // Existing start-session button
        Button(...) { ... }
    }
}
```

Mock references used by tests:
- MockObserveScheduleUseCase — Plan 01 scaffold (extend to expose subject):
```swift
final class MockObserveScheduleUseCase: ObserveScheduleUseCase, @unchecked Sendable {
    let subject = CurrentValueSubject<[Schedule], Never>([])
    func callAsFunction() -> AnyPublisher<[Schedule], Never> { subject.eraseToAnyPublisher() }
}
```
- MockToggleScheduleUseCase — Plan 01 scaffold (extend):
```swift
final class MockToggleScheduleUseCase: ToggleScheduleUseCase, @unchecked Sendable {
    private(set) var callCount = 0
    private(set) var lastScheduleId: UUID?
    private(set) var lastEnabled: Bool?
    var stubbedError: Error?
    func callAsFunction(scheduleId: UUID, enabled: Bool) async throws {
        callCount += 1
        lastScheduleId = scheduleId
        lastEnabled = enabled
        if let stubbedError { throw stubbedError }
    }
}
```
</interfaces>

<ux_decisions>
- **Empty state copy:** "Nie masz jeszcze harmonogramu. Życie samo się nie zablokuje." + primary button "Stwórz harmonogram".
- **Row layout:** `HStack` — text left ("Pn, Wt, Śr: 22:00 – 06:00"), enabled Toggle right. Whole row tappable → editTapped (except the Toggle itself).
- **Days label format helper:** `"Pn, Wt, Śr"` from sorted `daysOfWeek: [Int]` — map each weekday to PL abbrev (1→"Nd", 2→"Pn", ...) and join with ", ".
- **Time label format:** `"HH:MM – HH:MM"` zero-padded (e.g. `"09:00 – 17:00"`). If cross-midnight: append `" (nocna)"`.
- **Disabled row styling:** grey-out the text labels (secondary foreground) when `!schedule.enabled`. Toggle stays interactive.
- **MVP constraint:** schema supports N schedules; UI shows max 1 row (D-01). If schedules.count > 1, show first only — no multi-row UI in MVP. Actually: MVP should show whatever `schedules` publishes (0 or 1); if count > 1 (future), showing all is harmless but no add-button for additional rows (empty-state button only appears when count==0).
</ux_decisions>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: ScheduleListViewModel + 4 tests green</name>
  <files>
    DeluluDetox/Sources/Features/Scheduling/List/ViewModel/ScheduleListViewModel.swift,
    DeluluDetoxTests/Features/Scheduling/ScheduleListViewModelTests.swift
  </files>
  <read_first>
    - DeluluDetox/Sources/Features/Home/ViewModel/HomeViewModel.swift (analogue — @MainActor @Observable @CasePathable Destination with multiple VM cases + identity equality; subscribe-to-publisher pattern)
    - DeluluDetoxTests/Features/Home/HomeViewModelTests.swift (analogue — setUp registers mocks, awaits publisher emissions, assert destination matches)
    - DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ObserveScheduleUseCase.swift (consumed — returns AnyPublisher<[Schedule], Never>)
    - DeluluDetox/Sources/Features/Scheduling/Common/UseCase/ToggleScheduleUseCase.swift (consumed — `callAsFunction(scheduleId: UUID, enabled: Bool) async throws`)
    - DeluluDetox/Sources/Features/Scheduling/Editor/ViewModel/ScheduleEditorViewModel.swift (instantiated — init(existing: Schedule?))
  </read_first>
  <behavior>
    1. RED — Turn 4 XCTSkipIf stubs in ScheduleListViewModelTests into real assertions:

       ```swift
       @MainActor
       final class ScheduleListViewModelTests: XCTestCase {
           var mockObserve: MockObserveScheduleUseCase!
           var mockToggle: MockToggleScheduleUseCase!
           // + mocks ScheduleListViewModel's child ScheduleEditorViewModel will resolve @LazyInjected:
           var mockCreateOrUpdate: MockCreateOrUpdateScheduleUseCase!
           var mockObserveBlocklist: MockObserveBlocklistUseCase!

           override func setUp() async throws {
               mockObserve = MockObserveScheduleUseCase()
               mockToggle = MockToggleScheduleUseCase()
               mockCreateOrUpdate = MockCreateOrUpdateScheduleUseCase()
               mockObserveBlocklist = MockObserveBlocklistUseCase()
               mockObserveBlocklist.blocklistSubject.send(Blocklist.empty())

               DIContainer.shared.reset()
               DIContainer.shared.register(ObserveScheduleUseCase.self, scope: .unique) { _ in self.mockObserve }
               DIContainer.shared.register(ToggleScheduleUseCase.self, scope: .unique) { _ in self.mockToggle }
               DIContainer.shared.register(CreateOrUpdateScheduleUseCase.self, scope: .unique) { _ in self.mockCreateOrUpdate }
               DIContainer.shared.register(ObserveBlocklistUseCase.self, scope: .unique) { _ in self.mockObserveBlocklist }
           }

           override func tearDown() async throws {
               DIContainer.shared.reset()
           }

           // 4 tests
       }
       ```

       - `testListObservesScheduleRepositoryPublisher` — construct VM. Send `[Schedule(...)]` through `mockObserve.subject`. Assert `vm.schedules.count == 1` (allow 50ms delay for DispatchQueue.main).
       - `testTapEditExistingSetsEditorDestinationWithSchedule` — construct VM. Call `vm.editTapped(schedule)`. Assert `if case .scheduleEditor(let editorVM) = vm.destination { XCTAssertNotNil(editorVM) /* verify it was init'd with existing — tricky since ScheduleEditorViewModel has private editingId; can verify via editorVM.daysOfWeek matching Set(schedule.daysOfWeek) */ }`.
       - `testTapCreateNewSetsEditorDestinationWithNil` — construct VM. Call `vm.createTapped()`. Assert `if case .scheduleEditor(let editorVM) = vm.destination { XCTAssertTrue(editorVM.daysOfWeek.isEmpty) // nil existing → default init }`.
       - `testToggleRowCallsToggleScheduleUseCase` — construct VM. `await vm.toggleSchedule(scheduleId: someId, enabled: false)`. Assert `mockToggle.callCount == 1 && mockToggle.lastScheduleId == someId && mockToggle.lastEnabled == false`.

    2. GREEN — Create ScheduleListViewModel.swift per `<interfaces>`. No SwiftUI import.

    3. REFACTOR — none expected.

    4. `mcp__XcodeBuildMCP__test_sim` scoped: 4 passed.

    Commit: `feat(05-07): ship ScheduleListViewModel + 4 tests`.
  </behavior>
  <action>
    See `<behavior>`. Exact identifiers:
    - `final class ScheduleListViewModel: @unchecked Sendable` with `@MainActor @Observable`
    - `@CasePathable enum Destination { case scheduleEditor(ScheduleEditorViewModel); case errorAlert(String) }` with identity equality in `static func ==`
    - `@LazyInjected private var observeSchedule: ObserveScheduleUseCase`
    - `@LazyInjected private var toggleScheduleUC: ToggleScheduleUseCase` (rename to avoid shadowing the protocol typename if Swift complains)
    - `schedules: [Schedule] = []` via `private(set)`
    - Logger category: `"ScheduleList"`
    - `.receive(on: DispatchQueue.main)` on the sink (Plan 05-06 VM doesn't need it because sink closure reads/writes only VM state; List VM uses it for test determinism — BUT tests use `@MainActor` test class so it also runs on main; choose one. If tests flake, use `.receive(on: DispatchQueue.main)` and add a `try await Task.sleep(nanoseconds: 10_000_000)` in relevant tests)
  </action>
  <verify>
    <automated>mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox -only-testing:DeluluDetoxTests/Features/Scheduling/ScheduleListViewModelTests — expect 4 passed, 0 failed</automated>
  </verify>
  <acceptance_criteria>
    - `test -f DeluluDetox/Sources/Features/Scheduling/List/ViewModel/ScheduleListViewModel.swift` exits 0
    - `grep -c "final class ScheduleListViewModel" DeluluDetox/Sources/Features/Scheduling/List/ViewModel/ScheduleListViewModel.swift` == 1
    - `grep -c "@MainActor" DeluluDetox/Sources/Features/Scheduling/List/ViewModel/ScheduleListViewModel.swift` >= 1
    - `grep -c "@Observable" DeluluDetox/Sources/Features/Scheduling/List/ViewModel/ScheduleListViewModel.swift` == 1
    - `grep -c "case scheduleEditor(ScheduleEditorViewModel)" DeluluDetox/Sources/Features/Scheduling/List/ViewModel/ScheduleListViewModel.swift` == 1
    - `grep -c "^import SwiftUI" DeluluDetox/Sources/Features/Scheduling/List/ViewModel/ScheduleListViewModel.swift` == 0
    - `grep -c "@LazyInjected private var observeSchedule" DeluluDetox/Sources/Features/Scheduling/List/ViewModel/ScheduleListViewModel.swift` == 1
    - `grep -c "XCTSkipIf(true" DeluluDetoxTests/Features/Scheduling/ScheduleListViewModelTests.swift` == 0
    - `mcp__XcodeBuildMCP__test_sim` scoped: 4 passed, 0 failed, 0 skipped
  </acceptance_criteria>
  <done>
    ScheduleListViewModel exists. 4 tests green. Mocks (Observe/Toggle) complete. Committed.
  </done>
</task>

<task type="auto">
  <name>Task 2: ScheduleListView + HomeViewModel.scheduleList destination + HomeView toolbar entry + 1 new HomeView test</name>
  <files>
    DeluluDetox/Sources/Features/Scheduling/List/View/ScheduleListView.swift,
    DeluluDetox/Sources/Features/Home/ViewModel/HomeViewModel.swift,
    DeluluDetox/Sources/Features/Home/View/HomeView.swift,
    DeluluDetoxTests/Features/Home/HomeViewModelTests.swift
  </files>
  <read_first>
    - DeluluDetox/Sources/Features/Home/ViewModel/HomeViewModel.swift (the file being modified — existing Destination enum with 5 cases from Phase 3 Plan 06)
    - DeluluDetox/Sources/Features/Home/View/HomeView.swift (the file being modified — existing toolbar + 3 navigationDestinations from Phase 3 Plan 06, noting the `sessionStartDestination` @ViewBuilder extraction to avoid type-checker timeout)
    - DeluluDetox/Sources/Features/Scheduling/Editor/View/ScheduleEditorView.swift (child view the list navigates to)
    - DeluluDetox/Sources/Features/Scheduling/List/ViewModel/ScheduleListViewModel.swift (just created in Task 1 — bound to by ScheduleListView)
    - DeluluDetoxTests/Features/Home/HomeViewModelTests.swift (extending — add 1 test)
    - .planning/phases/03-quick-sessions/03-06-SUMMARY.md §Deviation 1 (HomeView body split pattern — if adding another destination causes Swift type-checker timeout, use @ViewBuilder extraction)
  </read_first>
  <action>
    Three edits + 1 new file:

    **1. Create `ScheduleListView.swift`:**
    ```swift
    import SwiftUI
    import SwiftUINavigation

    struct ScheduleListView: View {
        @Bindable var model: ScheduleListViewModel

        var body: some View {
            Group {
                if model.schedules.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(model.schedules) { schedule in
                            scheduleRow(schedule)
                        }
                    }
                }
            }
            .navigationTitle("Harmonogram")
            .navigationDestination(
                item: $model.destination.scheduleEditor
            ) { editorModel in
                ScheduleEditorView(model: editorModel) {
                    model.clearDestination()
                }
            }
            .alert(
                "Błąd",
                isPresented: errorAlertPresented,
                presenting: errorAlertMessage
            ) { _ in
                Button("OK") { model.clearDestination() }
            } message: { msg in Text(msg) }
        }

        @ViewBuilder
        private var emptyState: some View {
            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Nie masz jeszcze harmonogramu.")
                    .font(.headline)
                Text("Życie samo się nie zablokuje.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Stwórz harmonogram") {
                    model.createTapped()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.dayChipFilledBackground)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        @ViewBuilder
        private func scheduleRow(_ schedule: Schedule) -> some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(daysLabel(for: schedule))
                        .font(.headline)
                        .foregroundStyle(schedule.enabled ? .primary : .secondary)
                    Text(timeLabel(for: schedule))
                        .font(.subheadline)
                        .foregroundStyle(schedule.enabled ? .secondary : .tertiary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { schedule.enabled },
                    set: { newVal in
                        Task { await model.toggleSchedule(scheduleId: schedule.id, enabled: newVal) }
                    }
                ))
                .labelsHidden()
            }
            .contentShape(Rectangle())
            .onTapGesture { model.editTapped(schedule) }
        }

        // MARK: label helpers

        private static let plAbbrev: [Int: String] = [
            1: "Nd", 2: "Pn", 3: "Wt", 4: "Śr", 5: "Cz", 6: "Pt", 7: "Sb"
        ]

        private func daysLabel(for schedule: Schedule) -> String {
            // Display Mon-first even though array uses Calendar.weekday.
            let displayOrder = [2, 3, 4, 5, 6, 7, 1]
            let parts = displayOrder.compactMap { schedule.daysOfWeek.contains($0) ? Self.plAbbrev[$0] : nil }
            return parts.joined(separator: ", ")
        }

        private func timeLabel(for schedule: Schedule) -> String {
            let start = String(format: "%02d:%02d", schedule.startHour, schedule.startMinute)
            let end = String(format: "%02d:%02d", schedule.endHour, schedule.endMinute)
            let base = "\(start) – \(end)"
            return schedule.crossesMidnight ? base + " (nocna)" : base
        }

        private var errorAlertPresented: Binding<Bool> {
            Binding(
                get: { if case .errorAlert = model.destination { return true } else { return false } },
                set: { if !$0 { model.clearDestination() } }
            )
        }

        private var errorAlertMessage: String? {
            if case .errorAlert(let msg) = model.destination { return msg } else { return nil }
        }
    }
    ```

    **2. Modify `HomeViewModel.swift` — add `.scheduleList` case:**

    Locate the Destination enum declaration. Add ONE new case between existing cases (preserve order for diff readability):
    ```swift
    case scheduleList(ScheduleListViewModel)
    ```
    And add to the identity-equality switch in `static func ==`:
    ```swift
    case (.scheduleList(let a), .scheduleList(let b)): return a === b
    ```

    Add new method:
    ```swift
    func scheduleListTapped() {
        destination = .scheduleList(ScheduleListViewModel())
    }
    ```

    (No new @LazyInjected needed — ScheduleListViewModel resolves its own UCs via its init.)

    **3. Modify `HomeView.swift` — add toolbar button + navigationDestination:**

    Add a NEW ToolbarItem in the `.toolbar` block (place alongside the existing `play.circle.fill` start-session button):
    ```swift
    ToolbarItem(placement: .topBarLeading) {
        Button(action: { model.scheduleListTapped() }) {
            Image(systemName: "calendar")
        }
        .accessibilityLabel("Harmonogram")
    }
    ```

    Add `.navigationDestination(item: $model.destination.scheduleList)` — CAUTION: HomeView's existing body has 3 navigationDestinations (sessionStart, countdown) + sheets (sessionSuccess, picker) — adding a 4th modifier risks Swift type-checker timeout (Phase 3 Plan 06 hit this, solved via @ViewBuilder extraction). If build fails, extract `scheduleListDestination` into a @ViewBuilder func:
    ```swift
    @ViewBuilder
    private func scheduleListDestination(listModel: ScheduleListViewModel) -> some View {
        ScheduleListView(model: listModel)
    }
    ```
    And in body:
    ```swift
    .navigationDestination(item: $model.destination.scheduleList) { listModel in
        scheduleListDestination(listModel: listModel)
    }
    ```

    **4. Add 1 new test to HomeViewModelTests.swift:**
    ```swift
    func testScheduleListTappedRoutesToScheduleListDestination() async throws {
        // HomeViewModel mocks may need ObserveScheduleUseCase registration for
        // the inner ScheduleListViewModel's init.
        DIContainer.shared.register(ObserveScheduleUseCase.self, scope: .unique) { _ in MockObserveScheduleUseCase() }
        DIContainer.shared.register(ToggleScheduleUseCase.self, scope: .unique) { _ in MockToggleScheduleUseCase() }

        let vm = HomeViewModel()
        vm.scheduleListTapped()

        if case .scheduleList(let listVM) = vm.destination {
            XCTAssertNotNil(listVM)
        } else {
            XCTFail("Expected .scheduleList destination, got \(String(describing: vm.destination))")
        }
    }
    ```

    Note: existing HomeViewModelTests `setUp` may or may not register Scheduling mocks. Extend its setUp block to register them so all existing tests continue passing when HomeViewModel is expanded. If existing setUp registers only session + blocklist mocks, add Scheduling registrations alongside (minimal two: ObserveScheduleUseCase + ToggleScheduleUseCase).

    Build + test: `mcp__XcodeBuildMCP__test_sim` scheme=DeluluDetox — full suite green. HomeView build passes (may require @ViewBuilder extraction if type-checker times out).

    Commit: `feat(05-07): ship ScheduleListView + HomeView scheduleList nav integration`.
  </action>
  <verify>
    <automated>mcp__XcodeBuildMCP__test_sim scheme=DeluluDetox — expect 0 failures; HomeView build green; new test passes</automated>
  </verify>
  <acceptance_criteria>
    - `test -f DeluluDetox/Sources/Features/Scheduling/List/View/ScheduleListView.swift` exits 0
    - `grep -c "struct ScheduleListView: View" DeluluDetox/Sources/Features/Scheduling/List/View/ScheduleListView.swift` == 1
    - `grep -c "@Bindable var model: ScheduleListViewModel" DeluluDetox/Sources/Features/Scheduling/List/View/ScheduleListView.swift` == 1
    - `grep -c "Życie samo się nie zablokuje" DeluluDetox/Sources/Features/Scheduling/List/View/ScheduleListView.swift` == 1
    - `grep -c "Stwórz harmonogram" DeluluDetox/Sources/Features/Scheduling/List/View/ScheduleListView.swift` == 1
    - `grep -c "ScheduleEditorView(model: editorModel)" DeluluDetox/Sources/Features/Scheduling/List/View/ScheduleListView.swift` == 1
    - `grep -c "case scheduleList(ScheduleListViewModel)" DeluluDetox/Sources/Features/Home/ViewModel/HomeViewModel.swift` == 1
    - `grep -c "case (.scheduleList(let a), .scheduleList(let b)): return a === b" DeluluDetox/Sources/Features/Home/ViewModel/HomeViewModel.swift` == 1
    - `grep -c "func scheduleListTapped()" DeluluDetox/Sources/Features/Home/ViewModel/HomeViewModel.swift` == 1
    - `grep -c "scheduleListTapped\|calendar" DeluluDetox/Sources/Features/Home/View/HomeView.swift` >= 1 (new toolbar button wired)
    - `grep -c "navigationDestination(item: \$model.destination.scheduleList" DeluluDetox/Sources/Features/Home/View/HomeView.swift` == 1
    - `grep -c "testScheduleListTappedRoutesToScheduleListDestination" DeluluDetoxTests/Features/Home/HomeViewModelTests.swift` == 1
    - `mcp__XcodeBuildMCP__test_sim` full suite: 0 failures
  </acceptance_criteria>
  <done>
    List screen navigable from Home. Editor reachable from list (create + edit). Toggle works from row. Empty state copy in Polish. HomeView type-checker timeout mitigated if it occurred. Full suite green. Committed.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| List VM / publisher emissions | `observeSchedule()` delivers array from repository's in-memory subject; untrusted only if repo state is corrupted |
| Row Toggle / async Task | User can tap toggle repeatedly; each fire spawns a Task awaiting toggleScheduleUC |
| Home destination / list VM lifecycle | Creating ScheduleListViewModel on each tap is fine (@Observable); prior VM cancellables deallocate when destination clears |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-05-07-01 | Denial of Service | Row Toggle rapid-fire creates Task backlog | mitigate | ToggleScheduleUseCase is idempotent (upsert+sync); concurrent Tasks may produce duplicate sync calls but state converges; acceptable |
| T-05-07-02 | Tampering | Malformed Schedule render crashes row | mitigate | `daysLabel`/`timeLabel` use compactMap + String(format:); nil-safe; invalid hours clamp to 0..23 (fed from Int — no crash paths) |
| T-05-07-03 | Information Disclosure | List displays blocklistId-like UUIDs | accept | UUIDs not displayed; only day labels + times |
| T-05-07-04 | Spoofing | Row tap opens wrong editor | mitigate | `editTapped(schedule)` receives the exact Schedule struct by value; no id-lookup indirection |
| T-05-07-05 | Repudiation | Toggle failure lost | mitigate | logger.error on catch; errorAlert surfaces failure to user |
| T-05-07-06 | Denial of Service | HomeView Swift type-checker timeout | mitigate | @ViewBuilder extraction documented in action (Phase 3 Plan 06 pattern) |
</threat_model>

<verification>
1. `mcp__XcodeBuildMCP__test_sim` full suite — 0 failures. Test count grew by 5 (4 List VM + 1 Home VM).
2. `git log --oneline -2` shows 2 commits from this plan.
3. HomeView compiles with 4 navigationDestination modifiers (sessionStart + countdown + scheduleList + any sheet). If type-checker error, @ViewBuilder decomposition applied.
4. Empty state renders on fresh schedule.json (no schedules yet) with Polish sarcastic copy visible.
5. Toolbar has calendar icon in topBarLeading (Harmonogram entry) and play.circle.fill in topBarTrailing (existing session start).
</verification>

<success_criteria>
- ScheduleListViewModel observes publisher, instantiates editor VM on create/edit, toggles via UC.
- ScheduleListView renders rows + toggle + empty state + navigationDestination to editor.
- HomeViewModel has `.scheduleList` destination case + `scheduleListTapped()` entry.
- HomeView toolbar has calendar button → list → editor chain.
- 5 new tests green.
- No regressions in Phase 1-4 tests.
</success_criteria>

<output>
After completion, create `.planning/phases/05-scheduled-blocking/05-07-SUMMARY.md`. Document any HomeView @ViewBuilder extractions. Mention that UAT (Plan 05-08) will exercise the full Home → Harmonogram → Editor → Save → List flow on device.
</output>
