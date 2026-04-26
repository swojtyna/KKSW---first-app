import Foundation
import Testing
@testable import DeluluDetox

@Suite("ShieldActionHandler")
struct ShieldActionHandlerTests {

    private let handler = ShieldActionHandler()

    @Test("primary action returns .close")
    func primaryActionReturnsClose() {
        let decision = handler.decide(action: .primary, hasActiveSession: true)
        #expect(decision.response == .close)
    }

    @Test("secondary action returns .close with no URL")
    func secondaryActionReturnsClose() {
        let decision = handler.decide(action: .secondary, hasActiveSession: true)
        #expect(decision.response == .close)
        #expect(decision.urlToOpen == nil)
    }

    @Test("unknown action returns .close with no URL")
    func unknownActionReturnsClose() {
        let decision = handler.decide(action: .unknown, hasActiveSession: false)
        #expect(decision.response == .close)
        #expect(decision.urlToOpen == nil)
    }

    @Test("primary URL with active session is session/active")
    func primaryURLActiveSession() {
        let decision = handler.decide(action: .primary, hasActiveSession: true)
        #expect(decision.urlToOpen == URL(string: "deluludetox://session/active"))
    }

    @Test("primary URL without session is root")
    func primaryURLNoSession() {
        let decision = handler.decide(action: .primary, hasActiveSession: false)
        #expect(decision.urlToOpen == URL(string: "deluludetox://"))
    }
}
