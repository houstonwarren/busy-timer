import Foundation
import Observation

/// Drives a paced workout: a lead-in countdown, then one fixed-length interval
/// per rep until the target is reached or the user stops.
///
/// Timing is deadline-based rather than decrement-based: the engine stores the
/// wall-clock `Date` at which the current interval ends and derives the
/// remaining time from it on every tick. Pausing captures the remaining time
/// and resuming re-anchors the deadline, so a pause never resets the interval.
/// Chaining each new deadline off the previous one keeps long workouts free of
/// per-tick rounding drift.
///
/// All transitions accept an explicit `now` so tests can drive the engine with
/// synthetic dates (pass `autoTicks: false` to disable the internal timer).
@MainActor
@Observable
final class WorkoutEngine {
    enum Phase: Equatable {
        case ready
        case countingDown
        case running
        case paused
        case finished
    }

    let plan: WorkoutPlan
    let countdownDuration: TimeInterval

    private(set) var phase: Phase = .ready
    private(set) var completedReps = 0
    private(set) var timeRemaining: TimeInterval

    /// Called at the start of every rep interval (the moment to chime).
    var onRepStart: (() -> Void)?
    /// Called once when the final rep's interval elapses.
    var onFinish: (() -> Void)?

    private var deadline: Date?
    private var pausedRemaining: TimeInterval?
    private var phaseBeforePause: Phase = .running
    // nonisolated(unsafe): only mutated on the main actor; needed so deinit
    // (which is nonisolated) can invalidate the timer.
    @ObservationIgnored private nonisolated(unsafe) var tickTimer: Timer?
    private let autoTicks: Bool

    /// The rep currently being performed (1-based); 0 before the first rep starts.
    var currentRep: Int {
        switch phase {
        case .ready, .countingDown: 0
        case .finished: completedReps
        default: min(completedReps + 1, plan.targetReps)
        }
    }

    /// Fraction of the current interval (or countdown) still remaining, for progress rings.
    var intervalFractionRemaining: Double {
        let length = phase == .countingDown || (phase == .paused && phaseBeforePause == .countingDown)
            ? countdownDuration
            : plan.secondsPerRep
        guard length > 0 else { return 0 }
        return max(0, min(1, timeRemaining / length))
    }

    var isCountingDown: Bool {
        phase == .countingDown || (phase == .paused && phaseBeforePause == .countingDown)
    }

    init(plan: WorkoutPlan, countdownDuration: TimeInterval = 10, autoTicks: Bool = true) {
        self.plan = plan
        self.countdownDuration = countdownDuration
        self.autoTicks = autoTicks
        self.timeRemaining = countdownDuration
    }

    func start(now: Date = .now) {
        guard phase == .ready else { return }
        phase = .countingDown
        deadline = now.addingTimeInterval(countdownDuration)
        timeRemaining = countdownDuration
        startTicking()
    }

    func pause(now: Date = .now) {
        guard phase == .running || phase == .countingDown, let deadline else { return }
        phaseBeforePause = phase
        pausedRemaining = max(0, deadline.timeIntervalSince(now))
        timeRemaining = pausedRemaining ?? 0
        phase = .paused
        stopTicking()
    }

    func resume(now: Date = .now) {
        guard phase == .paused, let pausedRemaining else { return }
        deadline = now.addingTimeInterval(pausedRemaining)
        self.pausedRemaining = nil
        phase = phaseBeforePause
        startTicking()
    }

    /// Ends the workout early, keeping `completedReps` for the summary.
    func stop() {
        guard phase != .finished else { return }
        phase = .finished
        stopTicking()
    }

    func tick(now: Date = .now) {
        guard phase == .running || phase == .countingDown, var currentDeadline = deadline else { return }

        // Loop in case more than one interval elapsed since the last tick
        // (e.g. the app was suspended mid-workout).
        while now >= currentDeadline {
            switch phase {
            case .countingDown:
                phase = .running
                currentDeadline = currentDeadline.addingTimeInterval(plan.secondsPerRep)
                onRepStart?()
            case .running:
                completedReps += 1
                if completedReps >= plan.targetReps {
                    deadline = nil
                    timeRemaining = 0
                    phase = .finished
                    stopTicking()
                    onFinish?()
                    return
                }
                currentDeadline = currentDeadline.addingTimeInterval(plan.secondsPerRep)
                onRepStart?()
            default:
                return
            }
        }

        deadline = currentDeadline
        timeRemaining = max(0, currentDeadline.timeIntervalSince(now))
    }

    private func startTicking() {
        guard autoTicks else { return }
        stopTicking()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    private func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    deinit {
        tickTimer?.invalidate()
    }
}
