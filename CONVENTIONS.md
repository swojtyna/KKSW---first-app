# Swift Code Conventions

## MARK and private methods

Group private helper methods in a `private extension` with the `// MARK:` comment above the extension, not above individual methods inside the type body.

```swift
// ✅
final class SessionStartViewModel {
    func startTapped() { ... }
}

// MARK: - Private Helpers

private extension SessionStartViewModel {
    func resolveBlocklist() -> Blocklist { ... }
    func buildSessionRecord() -> SessionRecord { ... }
}

// ❌
final class SessionStartViewModel {
    func startTapped() { ... }

    // MARK: - Private Helpers

    private func resolveBlocklist() -> Blocklist { ... }
    private func buildSessionRecord() -> SessionRecord { ... }
}
```

Same rule applies in test files — private test helpers go in a `private extension` at the bottom of the file.
