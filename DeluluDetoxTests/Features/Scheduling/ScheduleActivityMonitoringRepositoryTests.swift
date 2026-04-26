import Foundation
@preconcurrency import DeviceActivity
import Testing
@testable import DeluluDetox

@Suite("LiveScheduleActivityMonitoringRepository")
@MainActor
struct ScheduleActivityMonitoringRepositoryTests {

    final class FakeCenter: DeviceActivityCenterRunner, @unchecked Sendable {
        var startedActivities: [(name: DeviceActivityName, schedule: DeviceActivitySchedule)] = []
        var stoppedActivities: [DeviceActivityName] = []
        var startError: Error?

        func startMonitoring(_ activity: DeviceActivityName, during schedule: DeviceActivitySchedule) throws {
            if let startError { throw startError }
            startedActivities.append((activity, schedule))
        }
        func stopMonitoring(_ activities: [DeviceActivityName]) {
            stoppedActivities.append(contentsOf: activities)
        }
    }

    struct TestError: Error, Equatable {}

    // MARK: - startMonitoring (single-day)

    @Test("single-day schedule uses .main segment and one DAS")
    func startMonitoringSingleDayUsesMainSegmentAndOneDAS() async throws {
        let fake = FakeCenter()
        let repo = LiveScheduleActivityMonitoringRepository(runner: fake)
        let schedule = makeSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)

        try await repo.startMonitoring(schedule: schedule)

        #expect(fake.startedActivities.count == 1)
        let (name, das) = try #require(fake.startedActivities.first)
        #expect(name.rawValue.hasSuffix(".\(ScheduleSegment.main.rawValue)"),
                "Single-day schedule MUST register the .main segment name — got \(name.rawValue)")
        #expect(das.repeats, "D-13 happy-path — DAS.repeats == true (Wave 0 Outcome A).")
        #expect(das.intervalStart.hour == 9)
        #expect(das.intervalStart.minute == 0)
        #expect(das.intervalEnd.hour == 17)
        #expect(das.intervalEnd.minute == 0)
    }

    // MARK: - startMonitoring (cross-midnight split)

    @Test("cross-midnight schedule splits into .evening and .morning DAS entries")
    func startMonitoringCrossMidnightSplitsIntoEveningAndMorningTwoDAS() async throws {
        let fake = FakeCenter()
        let repo = LiveScheduleActivityMonitoringRepository(runner: fake)
        let schedule = makeSchedule(startHour: 22, startMinute: 0, endHour: 6, endMinute: 0)

        try await repo.startMonitoring(schedule: schedule)

        #expect(fake.startedActivities.count == 2)

        let eveningEntry = fake.startedActivities.first(where: {
            $0.name.rawValue.hasSuffix(".\(ScheduleSegment.evening.rawValue)")
        })
        let morningEntry = fake.startedActivities.first(where: {
            $0.name.rawValue.hasSuffix(".\(ScheduleSegment.morning.rawValue)")
        })
        let evening = try #require(eveningEntry, "Missing .evening DAS for cross-midnight schedule.")
        let morning = try #require(morningEntry, "Missing .morning DAS for cross-midnight schedule.")

        #expect(evening.schedule.intervalStart.hour == 22)
        #expect(evening.schedule.intervalStart.minute == 0)
        #expect(evening.schedule.intervalEnd.hour == 23)
        #expect(evening.schedule.intervalEnd.minute == 59)
        #expect(evening.schedule.intervalEnd.second == 59)

        #expect(morning.schedule.intervalStart.hour == 0)
        #expect(morning.schedule.intervalStart.minute == 0)
        #expect(morning.schedule.intervalEnd.hour == 6)
        #expect(morning.schedule.intervalEnd.minute == 0)
    }

    // MARK: - repeats=true (Wave 0 Outcome A)

    @Test("all DAS entries use repeats=true per D-13")
    func startMonitoringUsesRepeatsTruePerD13() async throws {
        let fake = FakeCenter()
        let repo = LiveScheduleActivityMonitoringRepository(runner: fake)
        let singleDay = makeSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)
        let crossMidnight = makeSchedule(startHour: 22, startMinute: 0, endHour: 6, endMinute: 0)

        try await repo.startMonitoring(schedule: singleDay)
        try await repo.startMonitoring(schedule: crossMidnight)

        #expect(fake.startedActivities.count == 3)
        for entry in fake.startedActivities {
            #expect(entry.schedule.repeats,
                    "Wave 0 Outcome A — every DAS registered by ScheduleActivityMonitoringRepository MUST use repeats=true (D-13). Got repeats=false on \(entry.name.rawValue).")
        }
    }

    // MARK: - stopMonitoring

    @Test("stopMonitoring removes all 3 segment variants for schedule id")
    func stopMonitoringRemovesAllSegmentsForScheduleId() async throws {
        let fake = FakeCenter()
        let repo = LiveScheduleActivityMonitoringRepository(runner: fake)
        let id = UUID()

        await repo.stopMonitoring(scheduleId: id)

        let stoppedRaw = Set(fake.stoppedActivities.map { $0.rawValue })
        #expect(stoppedRaw.count == 3)
        #expect(stoppedRaw.contains("deluludetox.schedule.\(id.uuidString).main"))
        #expect(stoppedRaw.contains("deluludetox.schedule.\(id.uuidString).evening"))
        #expect(stoppedRaw.contains("deluludetox.schedule.\(id.uuidString).morning"))
    }

    // MARK: - Error wrapping

    @Test("startMonitoring wraps center error in repository error")
    func startMonitoringWrapsCenterErrorInRepositoryError() async {
        let fake = FakeCenter()
        fake.startError = TestError()
        let repo = LiveScheduleActivityMonitoringRepository(runner: fake)
        let schedule = makeSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)

        do {
            try await repo.startMonitoring(schedule: schedule)
            Issue.record("expected throw")
        } catch ScheduleActivityMonitoringError.startFailed(let inner) {
            #expect(inner is TestError, "Underlying error must be preserved for Plan 04 rollback logging.")
        } catch {
            Issue.record("wrong error type \(error)")
        }
    }

    // MARK: - buildDeviceActivitySchedules round-trip

    @Test("segment helper buildDeviceActivitySchedules round-trips correctly")
    func segmentHelperBuildDeviceActivitySchedulesRoundTrip() {
        let singleDay = makeSchedule(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)
        let crossMidnight = makeSchedule(startHour: 22, startMinute: 0, endHour: 6, endMinute: 0)

        let singlePairs = singleDay.buildDeviceActivitySchedules()
        #expect(singlePairs.count == 1)
        let parsedSingle = ScheduleActivityNames.parse(singlePairs[0].name)
        #expect(parsedSingle?.scheduleId == singleDay.id)
        #expect(parsedSingle?.segment == .main)

        let crossPairs = crossMidnight.buildDeviceActivitySchedules()
        #expect(crossPairs.count == 2)
        let parsed = crossPairs.compactMap { ScheduleActivityNames.parse($0.name) }
        #expect(parsed.count == 2)
        for p in parsed {
            #expect(p.scheduleId == crossMidnight.id)
        }
        let segments = Set(parsed.map { $0.segment })
        #expect(segments == [.evening, .morning])
    }
}

// MARK: - Private Helpers

private extension ScheduleActivityMonitoringRepositoryTests {
    func makeSchedule(
        startHour: Int, startMinute: Int,
        endHour: Int, endMinute: Int,
        id: UUID = UUID()
    ) -> Schedule {
        Schedule(
            id: id,
            name: nil,
            daysOfWeek: [2, 3, 4, 5, 6],
            startHour: startHour, startMinute: startMinute,
            endHour: endHour, endMinute: endMinute,
            enabled: true,
            blocklistId: UUID(),
            appVersion: "test"
        )
    }
}
