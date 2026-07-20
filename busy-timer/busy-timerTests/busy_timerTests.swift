import Foundation
import Testing
@testable import busy_timer

@MainActor
struct WorkoutEngineTests {
    private func makeEngine(
        reps: Int = 4,
        secondsPerRep: TimeInterval = 10,
        countdown: TimeInterval = 10
    ) -> WorkoutEngine {
        let plan = WorkoutPlan(
            targetReps: reps,
            burpeeType: .sixCount,
            totalDuration: secondsPerRep * Double(reps)
        )
        return WorkoutEngine(plan: plan, countdownDuration: countdown, autoTicks: false)
    }

    @Test func countdownLeadsIntoFirstRep() {
        let engine = makeEngine()
        var repStarts = 0
        engine.onRepStart = { repStarts += 1 }

        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        engine.start(now: t0)
        #expect(engine.phase == .countingDown)
        #expect(engine.timeRemaining == 10)

        engine.tick(now: t0.addingTimeInterval(4))
        #expect(engine.phase == .countingDown)
        #expect(abs(engine.timeRemaining - 6) < 0.001)

        engine.tick(now: t0.addingTimeInterval(10))
        #expect(engine.phase == .running)
        #expect(engine.currentRep == 1)
        #expect(repStarts == 1)
        #expect(abs(engine.timeRemaining - 10) < 0.001)
    }

    @Test func pausePreservesRemainingTimeInCurrentRep() {
        let engine = makeEngine()
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        engine.start(now: t0)
        engine.tick(now: t0.addingTimeInterval(10)) // countdown done, rep 1 begins

        engine.tick(now: t0.addingTimeInterval(13)) // 3s into rep 1
        engine.pause(now: t0.addingTimeInterval(13))
        #expect(engine.phase == .paused)
        #expect(abs(engine.timeRemaining - 7) < 0.001)

        // Resume much later: the rep continues with 7s left, it does not restart.
        engine.resume(now: t0.addingTimeInterval(100))
        engine.tick(now: t0.addingTimeInterval(100))
        #expect(abs(engine.timeRemaining - 7) < 0.001)

        engine.tick(now: t0.addingTimeInterval(103))
        #expect(abs(engine.timeRemaining - 4) < 0.001)
        #expect(engine.completedReps == 0)

        engine.tick(now: t0.addingTimeInterval(107)) // 7s after resume: rep 1 done
        #expect(engine.completedReps == 1)
        #expect(engine.currentRep == 2)
    }

    @Test func pauseDuringCountdownPreservesRemaining() {
        let engine = makeEngine()
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        engine.start(now: t0)
        engine.tick(now: t0.addingTimeInterval(4))
        engine.pause(now: t0.addingTimeInterval(4))
        #expect(engine.isCountingDown)
        #expect(abs(engine.timeRemaining - 6) < 0.001)

        engine.resume(now: t0.addingTimeInterval(50))
        engine.tick(now: t0.addingTimeInterval(56)) // countdown ends 6s after resume
        #expect(engine.phase == .running)
        #expect(engine.currentRep == 1)
    }

    @Test func completingAllRepsFinishesWorkout() {
        let engine = makeEngine(reps: 2, secondsPerRep: 10, countdown: 5)
        var repStarts = 0
        var finished = 0
        engine.onRepStart = { repStarts += 1 }
        engine.onFinish = { finished += 1 }

        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        engine.start(now: t0)
        engine.tick(now: t0.addingTimeInterval(5))  // rep 1 begins
        engine.tick(now: t0.addingTimeInterval(15)) // rep 2 begins
        #expect(engine.completedReps == 1)
        engine.tick(now: t0.addingTimeInterval(25)) // rep 2 done

        #expect(engine.phase == .finished)
        #expect(engine.completedReps == 2)
        #expect(repStarts == 2)
        #expect(finished == 1)
    }

    @Test func earlyStopKeepsCompletedReps() {
        let engine = makeEngine(reps: 5, secondsPerRep: 10, countdown: 5)
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        engine.start(now: t0)
        engine.tick(now: t0.addingTimeInterval(5))  // rep 1 begins
        engine.tick(now: t0.addingTimeInterval(25)) // reps 1 & 2 done, in rep 3

        engine.stop()
        #expect(engine.phase == .finished)
        #expect(engine.completedReps == 2)
    }

    @Test func catchesUpAfterLongGapBetweenTicks() {
        let engine = makeEngine(reps: 5, secondsPerRep: 10, countdown: 5)
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        engine.start(now: t0)
        engine.tick(now: t0.addingTimeInterval(5)) // rep 1 begins

        // No ticks for 21s (e.g. app suspended): reps 1 and 2 elapsed meanwhile.
        engine.tick(now: t0.addingTimeInterval(26))
        #expect(engine.completedReps == 2)
        #expect(engine.currentRep == 3)
        #expect(abs(engine.timeRemaining - 9) < 0.001)
    }

    @Test func pauseAndResumeAreNoOpsInWrongPhases() {
        let engine = makeEngine()
        engine.pause()
        #expect(engine.phase == .ready)
        engine.resume()
        #expect(engine.phase == .ready)

        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        engine.start(now: t0)
        engine.resume(now: t0.addingTimeInterval(1))
        #expect(engine.phase == .countingDown)
    }
}

@MainActor
struct WorkoutStoreTests {
    private func temporaryStoreURL() -> URL {
        URL.temporaryDirectory.appending(path: "workout-store-tests-\(UUID().uuidString).json")
    }

    private func makeWorkout(completedReps: Int = 47) -> Workout {
        Workout(
            date: Date(timeIntervalSince1970: 1_752_000_000), // whole seconds: survives ISO 8601 round-trip
            burpeeType: .tenCount,
            targetReps: 50,
            completedReps: completedReps,
            secondsPerRep: 24
        )
    }

    @Test func persistsAcrossInstances() throws {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = WorkoutStore(fileURL: url)
        store.add(makeWorkout())

        let reloaded = WorkoutStore(fileURL: url)
        #expect(reloaded.workouts == store.workouts)
        #expect(reloaded.workouts.first?.completedReps == 47)
    }

    @Test func deleteRemovesAndPersists() throws {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = WorkoutStore(fileURL: url)
        store.add(makeWorkout(completedReps: 10))
        store.add(makeWorkout(completedReps: 20))
        store.delete(atOffsets: IndexSet(integer: 0))

        let reloaded = WorkoutStore(fileURL: url)
        #expect(reloaded.workouts.count == 1)
        #expect(reloaded.workouts.first?.completedReps == 10)
    }

    @Test func newestWorkoutIsFirst() {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = WorkoutStore(fileURL: url)
        store.add(makeWorkout(completedReps: 1))
        store.add(makeWorkout(completedReps: 2))
        #expect(store.workouts.map(\.completedReps) == [2, 1])
        #expect(store.totalCompletedReps == 3)
    }
}
