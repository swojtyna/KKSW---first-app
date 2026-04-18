import Observation

@Observable
final class HomeViewModel {
    // Phase 1: empty state only. No data, no fetching.
    // Phase 2 will add: blocked app selections, FamilyActivityPicker trigger
    func chooseAppsTapped() {
        // No-op in Phase 1 -- wired to FamilyActivityPicker in Phase 2
    }
}
