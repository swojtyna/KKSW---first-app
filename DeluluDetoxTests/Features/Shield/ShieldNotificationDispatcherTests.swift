import XCTest
import UserNotifications
@testable import DeluluDetox

/// SHL-03 — pure request-builder unit tests for `ShieldNotificationDispatcher`.
///
/// Scope: ONLY the synchronous `makeRequest(url:)` path that builds a
/// `UNNotificationRequest` with the `userInfo["url"]` string + identifier
/// prefix. The async `dispatch(url:log:)` wrapper is intentionally NOT
/// unit-tested here because it just forwards to
/// `UNUserNotificationCenter.current().add(...)` — the contract under test
/// is "the request iOS sees is correct", not "our wrapper calls add".
final class ShieldNotificationDispatcherTests: XCTestCase {

    private let sut = ShieldNotificationDispatcher()

    // MARK: - userInfo payload

    func testDispatcher_buildRequest_sessionActiveURL_hasCorrectUserInfo() {
        let url = URL(string: "deluludetox://session/active")!
        let request = sut.makeRequest(url: url)

        XCTAssertEqual(
            request.content.userInfo["url"] as? String,
            "deluludetox://session/active",
            "userInfo[\"url\"] must round-trip the absoluteString so the delegate can reconstruct the URL."
        )
        XCTAssertTrue(
            request.identifier.hasPrefix("com.kksw.DeluluDetox.shield-deeplink."),
            "Identifier prefix must match the contract so the delegate can filter shield-originated taps."
        )
        XCTAssertNil(request.trigger, "Shield deep-link must deliver immediately — trigger must be nil.")
        XCTAssertEqual(
            request.content.title,
            "DeluluDetox",
            "Non-empty title — iOS silently drops notifications with empty title+body."
        )
        XCTAssertFalse(
            request.content.body.isEmpty,
            "Non-empty body — iOS silently drops notifications with empty title+body."
        )
        XCTAssertNil(
            request.content.sound,
            "Silent — shield is a UX pivot, not a ping (D-17 threat model T-04-06-03)."
        )
    }

    func testDispatcher_buildRequest_rootURL_hasCorrectUserInfo() {
        let url = URL(string: "deluludetox://")!
        let request = sut.makeRequest(url: url)

        XCTAssertEqual(
            request.content.userInfo["url"] as? String,
            "deluludetox://",
            "Root URL must round-trip exactly so the delegate can hand it to HomeViewModel.handleDeepLink."
        )
        XCTAssertTrue(
            request.identifier.hasPrefix("com.kksw.DeluluDetox.shield-deeplink."),
            "Identifier prefix must be stable across session-active and root URLs."
        )
    }

    // MARK: - Identifier uniqueness

    func testDispatcher_identifier_isUniquePerCall() {
        let url = URL(string: "deluludetox://session/active")!
        let a = sut.makeRequest(url: url)
        let b = sut.makeRequest(url: url)

        XCTAssertNotEqual(
            a.identifier,
            b.identifier,
            "Unique UUID suffix prevents iOS from coalescing rapid shield re-taps into a single notification (T-04-06-04)."
        )
    }
}
