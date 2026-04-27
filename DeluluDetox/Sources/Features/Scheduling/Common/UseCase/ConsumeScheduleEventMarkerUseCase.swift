import Foundation
import os

/// Main-app foreground entry point for draining the DAM event markers.
/// The repository already owns "list + sort + delete" (Plan 05-02 Task 1);
/// this UC translates each `ScheduleEventMarker` into a `ScheduleEvent`
/// and appends it to `schedule_events.json`. Order is preserved from the
/// repository's chronological return value (RESEARCH OQ#4).
final class ConsumeScheduleEventMarkerUseCaseImpl: ConsumeScheduleEventMarkerUseCase, @unchecked Sendable {
    private let repository: ScheduleRepository

    private static let log = Logger(
        subsystem: "com.kksw.DeluluDetox",
        category: "ConsumeScheduleEventMarkerUseCase"
    )

    init(repository: ScheduleRepository) {
        self.repository = repository
    }

    @discardableResult
    func execute() async throws -> Int {
        let markers = try await repository.consumeEventMarkers()
        for marker in markers {
            let event = ScheduleEvent(
                scheduleId: marker.scheduleId,
                kind: marker.kind == .started ? .started : .ended,
                timestamp: marker.timestamp
            )
            try await repository.appendEvent(event)
        }
        Self.log.info("markers consumed count=\(markers.count, privacy: .public)")
        return markers.count
    }
}
