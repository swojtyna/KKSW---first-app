import XCTest
import Foundation
@testable import DeluluDetox

/// Tests for SHL-03 (action handler). Plan 03 must:
///   1) Extract pure logic into `ShieldActionHandler` struct in the main-app target,
///      with method `handle(action: ShieldActionKind, hasActiveSession: Bool) -> ShieldActionResult`
///      where `ShieldActionResult = (response: ResponseKind, urlToOpen: URL?)`.
///      `ResponseKind` mirrors `ShieldActionResponse` cases (`.close`, `.defer`, `.none`).
///   2) The extension class delegates to this struct so behavior is XCTest-unit-testable.
///
/// Until Plan 03 ships, these tests skip — keeping the suite green.
final class ShieldActionHandlerTests: XCTestCase {
    func testPrimaryAction_returnsClose() throws {
        try XCTSkipIf(true, "Plan 03 will implement ShieldActionHandler. Expected: handle(.primary, hasActiveSession: true).response == .close.")
    }
    func testSecondaryAction_returnsClose() throws {
        try XCTSkipIf(true, "Plan 03 will implement ShieldActionHandler. Expected: handle(.secondary, hasActiveSession: true).response == .close.")
    }
    func testUnknownAction_returnsClose() throws {
        try XCTSkipIf(true, "Plan 03 will implement defensive @unknown default. Expected: handle(.unknown, hasActiveSession: false).response == .close.")
    }
    func testPrimaryURL_activeSession_isSessionActive() throws {
        try XCTSkipIf(true, "Plan 03 will implement URL switch. Expected: handle(.primary, hasActiveSession: true).urlToOpen == URL(string: \"deluludetox://session/active\").")
    }
    func testPrimaryURL_noSession_isRoot() throws {
        try XCTSkipIf(true, "Plan 03 will implement URL switch. Expected: handle(.primary, hasActiveSession: false).urlToOpen == URL(string: \"deluludetox://\").")
    }
}
