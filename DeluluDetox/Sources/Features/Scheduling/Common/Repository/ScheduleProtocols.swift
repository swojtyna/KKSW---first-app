// Features/Scheduling/Common/Repository/ScheduleProtocols.swift
//
// Empty Scheduling protocols declared up-front so Plan 05-01 test mocks
// compile against real type names. Plans 05-02 / 05-03 / 05-04 REPLACE
// the empty protocol bodies with the actual method declarations.
//
// Downstream plans must NOT create new files for these protocols — they
// extend the declarations below in-place so conformers (Live* + Mock*)
// stay in sync automatically.

import Combine
import Foundation

protocol ScheduleRepository: Sendable {
    var schedulesPublisher: AnyPublisher<[Schedule], Never> { get }
}

protocol ScheduleShieldRepository: Sendable {}

protocol ScheduleActivityMonitoringRepository: Sendable {}

protocol ObserveScheduleUseCase: Sendable {}

protocol CreateOrUpdateScheduleUseCase: Sendable {}

protocol ToggleScheduleUseCase: Sendable {}

protocol SyncScheduleWithSystemUseCase: Sendable {}

protocol SelfHealSchedulesUseCase: Sendable {}

protocol ComputeScheduleWindowUseCase: Sendable {}

protocol ConsumeScheduleEventMarkerUseCase: Sendable {}
