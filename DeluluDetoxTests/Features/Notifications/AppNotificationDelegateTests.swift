import Foundation
import UserNotifications
import Testing
@testable import DeluluDetox

@Suite("AppNotificationDelegate")
@MainActor
struct AppNotificationDelegateTests {

    final class HandlerSpy: @unchecked Sendable {
        private(set) var receivedURLs: [URL] = []
        private let lock = NSLock()
        func handle(url: URL) {
            lock.lock(); defer { lock.unlock() }
            receivedURLs.append(url)
        }
    }

    // MARK: - presentationOptions (willPresent seam)

    @Test("shield deep-link prefix returns .banner")
    func willPresent_shieldDeepLinkPrefix_returnsBanner() {
        let (sut, _) = makeSUT()
        let options = sut.presentationOptions(forIdentifier: "com.kksw.DeluluDetox.shield-deeplink.XYZ")
        #expect(options == [.banner])
    }

    @Test("session end prefix returns empty options")
    func willPresent_sessionEndPrefix_returnsEmpty() {
        let (sut, _) = makeSUT()
        let options = sut.presentationOptions(forIdentifier: "session.end.ABC")
        #expect(options == [])
    }

    @Test("schedule start prefix returns .banner and .sound")
    func willPresent_scheduleStartPrefix_returnsBannerSound() {
        let (sut, _) = makeSUT()
        let options = sut.presentationOptions(forIdentifier: "schedule.start.DEF.2")
        #expect(options == [.banner, .sound])
    }

    @Test("unknown prefix returns empty options")
    func willPresent_unknownPrefix_returnsEmpty() {
        let (sut, _) = makeSUT()
        let options = sut.presentationOptions(forIdentifier: "unknown.foo")
        #expect(options == [])
    }

    // MARK: - dispatchResponse (didReceive seam)

    @Test("shield deep-link prefix forwards valid URL")
    func didReceive_shieldDeepLinkPrefix_forwardsValidURL() async {
        let (sut, spy) = makeSUT()

        await sut.dispatchResponse(
            identifier: "com.kksw.DeluluDetox.shield-deeplink.ABC",
            urlString: "deluludetox://shield"
        )

        #expect(spy.receivedURLs.map(\.absoluteString) == ["deluludetox://shield"])
    }

    @Test("shield deep-link prefix with invalid scheme not forwarded")
    func didReceive_shieldDeepLinkPrefix_invalidScheme_notForwarded() async {
        let (sut, spy) = makeSUT()

        await sut.dispatchResponse(
            identifier: "com.kksw.DeluluDetox.shield-deeplink.ABC",
            urlString: "https://example.com"
        )

        #expect(spy.receivedURLs.isEmpty)
    }

    @Test("shield deep-link prefix with missing userInfo not forwarded")
    func didReceive_shieldDeepLinkPrefix_missingUserInfo_notForwarded() async {
        let (sut, spy) = makeSUT()

        await sut.dispatchResponse(
            identifier: "com.kksw.DeluluDetox.shield-deeplink.ABC",
            urlString: nil
        )

        #expect(spy.receivedURLs.isEmpty)
    }

    @Test("session end prefix does NOT invoke shield handler")
    func didReceive_sessionEndPrefix_doesNotInvokeShieldHandler() async {
        let (sut, spy) = makeSUT()

        await sut.dispatchResponse(
            identifier: "session.end.ABC",
            urlString: "deluludetox://session"
        )

        #expect(spy.receivedURLs.isEmpty, "engagement notifications MUST NOT go through shield handler")
    }

    @Test("schedule start prefix does NOT invoke shield handler")
    func didReceive_scheduleStartPrefix_doesNotInvokeShieldHandler() async {
        let (sut, spy) = makeSUT()

        await sut.dispatchResponse(
            identifier: "schedule.start.ABC.2",
            urlString: nil
        )

        #expect(spy.receivedURLs.isEmpty)
    }
}

// MARK: - Private Helpers

private extension AppNotificationDelegateTests {
    func makeSUT() -> (AppNotificationDelegate, HandlerSpy) {
        let spy = HandlerSpy()
        let sut = AppNotificationDelegate(shieldDeepLinkHandler: { url in spy.handle(url: url) })
        return (sut, spy)
    }
}
