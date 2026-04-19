import Combine
@preconcurrency import FamilyControls
@testable import DeluluDetox

final class MockBlocklistRepository: BlocklistRepository, @unchecked Sendable {
    var stubbedBlocklist: Blocklist {
        didSet { blocklistSubject.send(stubbedBlocklist) }
    }
    var updateError: Error?
    var removeError: Error?
    var reconcileError: Error?

    private(set) var updateCallCount = 0
    private(set) var removeCallCount = 0
    private(set) var reconcileCallCount = 0
    private(set) var capturedUpdateSelection: FamilyActivitySelection?
    private(set) var capturedRemoveRecordID: TokenRecord.ID?

    private let blocklistSubject: CurrentValueSubject<Blocklist, Never>

    var blocklistPublisher: AnyPublisher<Blocklist, Never> {
        blocklistSubject.eraseToAnyPublisher()
    }

    init(initial: Blocklist = .empty()) {
        self.stubbedBlocklist = initial
        self.blocklistSubject = CurrentValueSubject(initial)
    }

    func update(with selection: FamilyActivitySelection) async throws {
        updateCallCount += 1
        capturedUpdateSelection = selection
        if let updateError { throw updateError }
        stubbedBlocklist = stubbedBlocklist.merging(selection: selection)
    }

    func remove(recordID: TokenRecord.ID) async throws {
        removeCallCount += 1
        capturedRemoveRecordID = recordID
        if let removeError { throw removeError }
        var next = stubbedBlocklist
        next.records.removeAll { $0.id == recordID }
        stubbedBlocklist = next
    }

    func reconcile() async throws {
        reconcileCallCount += 1
        if let reconcileError { throw reconcileError }
        stubbedBlocklist = stubbedBlocklist.reconcileTokenPointers()
    }
}
