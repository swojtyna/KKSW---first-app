import Foundation
import UserNotifications
import Testing
@testable import DeluluDetox

@Suite("LiveShieldNotificationRepository")
struct ShieldNotificationRepositoryTests {

    private let sut = LiveShieldNotificationRepository()

    // MARK: - userInfo payload

    @Test("session/active URL has correct userInfo")
    func repository_buildRequest_sessionActiveURL_hasCorrectUserInfo() {
        let url = URL(string: "deluludetox://session/active")!
        let request = sut.makeRequest(url: url)

        #expect(
            request.content.userInfo["url"] as? String == "deluludetox://session/active",
            "userInfo[\"url\"] must round-trip the absoluteString so the delegate can reconstruct the URL."
        )
        #expect(
            request.identifier.hasPrefix("com.kksw.DeluluDetox.shield-deeplink."),
            "Identifier prefix must match the contract so the delegate can filter shield-originated taps."
        )
        #expect(request.trigger == nil, "Shield deep-link must deliver immediately — trigger must be nil.")
        #expect(
            request.content.title == "DeluluDetox",
            "Non-empty title — iOS silently drops notifications with empty title+body."
        )
        #expect(!request.content.body.isEmpty, "Non-empty body — iOS silently drops notifications with empty title+body.")
        #expect(request.content.sound == nil, "Silent — shield is a UX pivot, not a ping.")
    }

    @Test("root URL has correct userInfo")
    func repository_buildRequest_rootURL_hasCorrectUserInfo() {
        let url = URL(string: "deluludetox://")!
        let request = sut.makeRequest(url: url)

        #expect(
            request.content.userInfo["url"] as? String == "deluludetox://",
            "Root URL must round-trip exactly so the delegate can hand it to HomeViewModel.handleDeepLink."
        )
        #expect(
            request.identifier.hasPrefix("com.kksw.DeluluDetox.shield-deeplink."),
            "Identifier prefix must be stable across session-active and root URLs."
        )
    }

    // MARK: - Identifier uniqueness

    @Test("identifier is unique per call")
    func repository_identifier_isUniquePerCall() {
        let url = URL(string: "deluludetox://session/active")!
        let a = sut.makeRequest(url: url)
        let b = sut.makeRequest(url: url)

        #expect(
            a.identifier != b.identifier,
            "Unique UUID suffix prevents iOS from coalescing rapid shield re-taps."
        )
    }

    // MARK: - Constants contract

    @Test("constants match shared contract")
    func constants_matchSharedContract() {
        #expect(ShieldNotificationConstants.identifierPrefix == "com.kksw.DeluluDetox.shield-deeplink.")
        #expect(ShieldNotificationConstants.userInfoURLKey == "url")
    }
}
