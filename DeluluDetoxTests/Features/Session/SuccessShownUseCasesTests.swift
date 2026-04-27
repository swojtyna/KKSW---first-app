import Foundation
import Testing
@testable import DeluluDetox

@Suite(.serialized)
final class SuccessShownUseCasesTests {

    let suiteName: String
    let suite: UserDefaults

    init() {
        suiteName = "test.successShown.\(UUID().uuidString)"
        suite = UserDefaults(suiteName: suiteName)!
        suite.dictionaryRepresentation().keys.forEach { suite.removeObject(forKey: $0) }
        MarkSuccessShownUseCaseImpl.defaultsOverride = suite
    }

    deinit {
        MarkSuccessShownUseCaseImpl.defaultsOverride = nil
        suite.removePersistentDomain(forName: suiteName)
    }

    @Test("mark success shown persists flag to UserDefaults")
    func markSuccessShownPersistsFlagToUserDefaults() {
        let id = UUID()
        let markUC = MarkSuccessShownUseCaseImpl()
        let checkUC = CheckSuccessShownUseCaseImpl()

        #expect(!checkUC.execute(sessionId: id))
        markUC.execute(sessionId: id)
        #expect(checkUC.execute(sessionId: id))
    }

    @Test("check success shown returns false for unmarked session")
    func checkSuccessShownReturnsFalseForUnmarkedSession() {
        #expect(!CheckSuccessShownUseCaseImpl().execute(sessionId: UUID()))
    }

    @Test("mark and check are independent per sessionId")
    func markAndCheckAreIndependentPerSessionId() {
        let a = UUID()
        let b = UUID()
        let markUC = MarkSuccessShownUseCaseImpl()
        let checkUC = CheckSuccessShownUseCaseImpl()

        markUC.execute(sessionId: a)
        #expect(checkUC.execute(sessionId: a))
        #expect(!checkUC.execute(sessionId: b))
    }

    @Test("mock mark captures calls without touching UserDefaults")
    func mockMarkSuccessShownCapturesCallsWithoutTouchingUserDefaults() {
        let mockMark = MockMarkSuccessShownUseCase()
        let id = UUID()
        mockMark.execute(sessionId: id)
        #expect(mockMark.callCount == 1)
        #expect(mockMark.lastSessionId == id)
        #expect(mockMark.allMarked.contains(id))
        #expect(!CheckSuccessShownUseCaseImpl().execute(sessionId: id))
    }
}
