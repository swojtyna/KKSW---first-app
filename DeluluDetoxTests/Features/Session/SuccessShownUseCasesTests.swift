import XCTest
@testable import DeluluDetox

final class SuccessShownUseCasesTests: XCTestCase {

    private var suiteName: String!

    override func setUp() {
        super.setUp()
        // Fresh in-memory-ish UserDefaults suite per test — don't leak across runs.
        suiteName = "test.successShown.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        // Clear any persisted keys (shouldn't exist for a fresh suite, belt-and-suspenders).
        suite.dictionaryRepresentation().keys.forEach { suite.removeObject(forKey: $0) }
        MarkSuccessShownUseCaseImpl.defaultsOverride = suite
    }

    override func tearDown() {
        MarkSuccessShownUseCaseImpl.defaultsOverride = nil
        if let suiteName {
            UserDefaults().removePersistentDomain(forName: suiteName)
        }
        suiteName = nil
        super.tearDown()
    }

    func testMarkSuccessShownPersistsFlagToUserDefaults() {
        let id = UUID()
        let markUC = MarkSuccessShownUseCaseImpl()
        let checkUC = CheckSuccessShownUseCaseImpl()

        XCTAssertFalse(checkUC(sessionId: id))
        markUC(sessionId: id)
        XCTAssertTrue(checkUC(sessionId: id))
    }

    func testCheckSuccessShownReturnsFalseForUnmarkedSession() {
        let checkUC = CheckSuccessShownUseCaseImpl()
        XCTAssertFalse(checkUC(sessionId: UUID()))
    }

    func testMarkAndCheckAreIndependentPerSessionId() {
        let a = UUID()
        let b = UUID()
        let markUC = MarkSuccessShownUseCaseImpl()
        let checkUC = CheckSuccessShownUseCaseImpl()

        markUC(sessionId: a)
        XCTAssertTrue(checkUC(sessionId: a))
        XCTAssertFalse(checkUC(sessionId: b))
    }

    func testMockMarkSuccessShownCapturesCallsWithoutTouchingUserDefaults() {
        // Parity check: the mock records the id but does not write to UserDefaults.
        let mockMark = MockMarkSuccessShownUseCase()
        let id = UUID()
        mockMark(sessionId: id)
        XCTAssertEqual(mockMark.callCount, 1)
        XCTAssertEqual(mockMark.lastSessionId, id)
        XCTAssertTrue(mockMark.allMarked.contains(id))

        // Real CheckSuccessShownUseCaseImpl backed by the override suite should NOT see it.
        XCTAssertFalse(CheckSuccessShownUseCaseImpl()(sessionId: id))
    }
}
