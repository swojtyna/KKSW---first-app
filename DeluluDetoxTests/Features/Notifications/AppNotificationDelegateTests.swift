import XCTest
import UserNotifications
@testable import DeluluDetox

@MainActor
final class AppNotificationDelegateTests: XCTestCase {

    // Spy for the shield deep-link handler — captures every URL the delegate
    // forwards. Thread-safe because multiple Task hops may touch it.
    final class HandlerSpy: @unchecked Sendable {
        private(set) var receivedURLs: [URL] = []
        private let lock = NSLock()
        func handle(url: URL) {
            lock.lock(); defer { lock.unlock() }
            receivedURLs.append(url)
        }
    }

    private func makeSUT() -> (AppNotificationDelegate, HandlerSpy) {
        let spy = HandlerSpy()
        let sut = AppNotificationDelegate(shieldDeepLinkHandler: { url in spy.handle(url: url) })
        return (sut, spy)
    }

    // MARK: - presentationOptions (willPresent seam)

    func testWillPresent_shieldDeepLinkPrefix_returnsBanner() {
        let (sut, _) = makeSUT()
        let options = sut.presentationOptions(forIdentifier: "com.kksw.DeluluDetox.shield-deeplink.XYZ")
        XCTAssertEqual(options, [.banner])
    }

    func testWillPresent_sessionEndPrefix_returnsEmpty() {
        let (sut, _) = makeSUT()
        let options = sut.presentationOptions(forIdentifier: "session.end.ABC")
        XCTAssertEqual(options, [])
    }

    func testWillPresent_scheduleStartPrefix_returnsBannerSound() {
        let (sut, _) = makeSUT()
        let options = sut.presentationOptions(forIdentifier: "schedule.start.DEF.2")
        XCTAssertEqual(options, [.banner, .sound])
    }

    func testWillPresent_unknownPrefix_returnsEmpty() {
        let (sut, _) = makeSUT()
        let options = sut.presentationOptions(forIdentifier: "unknown.foo")
        XCTAssertEqual(options, [])
    }

    // MARK: - dispatchResponse (didReceive seam)

    func testDidReceive_shieldDeepLinkPrefix_forwardsValidURL() async {
        let (sut, spy) = makeSUT()

        await sut.dispatchResponse(
            identifier: "com.kksw.DeluluDetox.shield-deeplink.ABC",
            userInfo: ["url": "deluludetox://shield"]
        )

        XCTAssertEqual(spy.receivedURLs.map(\.absoluteString), ["deluludetox://shield"])
    }

    func testDidReceive_shieldDeepLinkPrefix_invalidScheme_notForwarded() async {
        let (sut, spy) = makeSUT()

        await sut.dispatchResponse(
            identifier: "com.kksw.DeluluDetox.shield-deeplink.ABC",
            userInfo: ["url": "https://example.com"]
        )

        XCTAssertTrue(spy.receivedURLs.isEmpty)
    }

    func testDidReceive_shieldDeepLinkPrefix_missingUserInfo_notForwarded() async {
        let (sut, spy) = makeSUT()

        await sut.dispatchResponse(
            identifier: "com.kksw.DeluluDetox.shield-deeplink.ABC",
            userInfo: [:]
        )

        XCTAssertTrue(spy.receivedURLs.isEmpty)
    }

    func testDidReceive_sessionEndPrefix_doesNotInvokeShieldHandler() async {
        let (sut, spy) = makeSUT()

        await sut.dispatchResponse(
            identifier: "session.end.ABC",
            userInfo: ["url": "deluludetox://session"]
        )

        XCTAssertTrue(spy.receivedURLs.isEmpty, "engagement notifications MUST NOT go through shield handler")
    }

    func testDidReceive_scheduleStartPrefix_doesNotInvokeShieldHandler() async {
        let (sut, spy) = makeSUT()

        await sut.dispatchResponse(
            identifier: "schedule.start.ABC.2",
            userInfo: [:]
        )

        XCTAssertTrue(spy.receivedURLs.isEmpty)
    }
}
