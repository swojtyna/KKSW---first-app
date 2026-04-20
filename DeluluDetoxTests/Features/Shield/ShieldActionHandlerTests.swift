import XCTest
import Foundation
@testable import DeluluDetox

/// SHL-03 — pure decision logic unit tests.
final class ShieldActionHandlerTests: XCTestCase {

    private let handler = ShieldActionHandler()

    func testPrimaryAction_returnsClose() {
        let decision = handler.decide(action: .primary, hasActiveSession: true)
        XCTAssertEqual(decision.response, .close)
    }

    func testSecondaryAction_returnsClose() {
        let decision = handler.decide(action: .secondary, hasActiveSession: true)
        XCTAssertEqual(decision.response, .close)
        XCTAssertNil(decision.urlToOpen, "Secondary action must NOT open a URL.")
    }

    func testUnknownAction_returnsClose() {
        let decision = handler.decide(action: .unknown, hasActiveSession: false)
        XCTAssertEqual(decision.response, .close)
        XCTAssertNil(decision.urlToOpen, "Unknown action must NOT open a URL.")
    }

    func testPrimaryURL_activeSession_isSessionActive() {
        let decision = handler.decide(action: .primary, hasActiveSession: true)
        XCTAssertEqual(decision.urlToOpen, URL(string: "deluludetox://session/active"))
    }

    func testPrimaryURL_noSession_isRoot() {
        let decision = handler.decide(action: .primary, hasActiveSession: false)
        XCTAssertEqual(decision.urlToOpen, URL(string: "deluludetox://"))
    }
}
