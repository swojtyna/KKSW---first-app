import Combine
import Foundation

/// Thin publisher pass-through over `ScheduleRepository.schedulesPublisher`.
/// ViewModels (ScheduleListViewModel in Plan 05-07) consume this UC instead
/// of the repository to honor the CLAUDE.md "VM → only UseCase" rule.
final class ObserveScheduleUseCaseImpl: ObserveScheduleUseCase, @unchecked Sendable {
    private let repository: ScheduleRepository

    init(repository: ScheduleRepository) {
        self.repository = repository
    }

    func callAsFunction() -> AnyPublisher<[Schedule], Never> {
        repository.schedulesPublisher
    }
}
