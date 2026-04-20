import Foundation

/// Pure decision struct for SHL-03. The extension class wraps this with the
/// thin `ShieldActionDelegate` glue that translates `ShieldAction` to
/// `ShieldActionKind`, calls `decide(...)`, performs `extensionContext?.open`
/// for the URL (if any), then invokes the completion with the response.
///
/// Extracting the contract here keeps the extension to glue-only and lets
/// XCTest cover SHL-03 without spinning up an extension process.
struct ShieldActionHandler {

    // MARK: - Public contract

    enum ActionKind {
        case primary
        case secondary
        case unknown
    }

    enum ResponseKind: Equatable {
        case close
        case deferResponse  // mirror ShieldActionResponse.defer (renamed to avoid Swift `defer` keyword)
        case none
    }

    struct Decision: Equatable {
        let response: ResponseKind
        let urlToOpen: URL?
    }

    // MARK: - Decision logic

    /// SHL-03 decision matrix per CONTEXT §D-05/D-06/D-07/D-13/D-15:
    /// - primary + active   → open `deluludetox://session/active`, then close.
    /// - primary + no-active → open `deluludetox://`, then close.
    /// - secondary           → close (no URL).
    /// - unknown             → close (defensive default).
    func decide(action: ActionKind, hasActiveSession: Bool) -> Decision {
        switch action {
        case .primary:
            let url = hasActiveSession
                ? URL(string: "deluludetox://session/active")!
                : URL(string: "deluludetox://")!
            return Decision(response: .close, urlToOpen: url)
        case .secondary:
            return Decision(response: .close, urlToOpen: nil)
        case .unknown:
            return Decision(response: .close, urlToOpen: nil)
        }
    }
}

/// Cheap, allocation-free test for active-session presence used by the
/// extension. Returns `true` iff `active_session.json` exists and contains
/// at least 1 byte. Does NOT decode the contents — full decoding lives in
/// `ActiveSessionEnvelopeReader.loadRemainingMinutes()` (used by the
/// configuration extension only). The action extension only needs a yes/no.
enum ShieldActionSessionProbe {
    static func hasActiveSession() -> Bool {
        guard let url = try? SessionPaths.activeSessionURL(),
              let data = try? Data(contentsOf: url),
              !data.isEmpty
        else { return false }
        return true
    }
}
