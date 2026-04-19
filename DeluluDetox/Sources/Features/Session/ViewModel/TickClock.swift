import Foundation

protocol TickCancellable: AnyObject, Sendable {
    func cancel()
}

protocol TickClock: Sendable {
    @MainActor
    func schedule(interval: TimeInterval, onTick: @escaping @MainActor () -> Void) -> any TickCancellable
}

/// Production — DispatchSourceTimer on the main queue. Cancels on deinit.
final class SystemTickClock: TickClock, @unchecked Sendable {
    @MainActor
    func schedule(interval: TimeInterval, onTick: @escaping @MainActor () -> Void) -> any TickCancellable {
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(50))
        source.setEventHandler {
            MainActor.assumeIsolated { onTick() }
        }
        source.resume()
        return TimerToken(source: source)
    }

    private final class TimerToken: TickCancellable, @unchecked Sendable {
        private let source: DispatchSourceTimer
        private var cancelled = false
        init(source: DispatchSourceTimer) { self.source = source }
        func cancel() {
            guard !cancelled else { return }
            cancelled = true
            source.cancel()
        }
        deinit { cancel() }
    }
}
