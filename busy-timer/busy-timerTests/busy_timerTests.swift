import Foundation
import Testing
@testable import busy_timer

@MainActor
struct WorkoutEngineTests {
    private func makeEngine(
        reps: Int = 4,
        secondsPerRep: TimeInterval = 10,
        countdown: TimeInterval = 10,
        repsPerChime: Int = 1
    ) -> WorkoutEngine {
        let plan = WorkoutPlan(
            targetReps: reps,
            burpeeType: .sixCount,
            repsPerChime: repsPerChime,
            totalDuration: secondsPerRep * Double(reps)
        )
        return WorkoutEngine(plan: plan, countdownDuration: countdown, autoTicks: false)
    }

    @Test func countdownLeadsIntoFirstRep() {
        let engine = makeEngine()
        var chimes = 0
        engine.onChime = { chimes += 1 }

        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        engine.start(now: t0)
        #expect(engine.phase == .countingDown)
        #expect(engine.timeRemaining == 10)

        engine.tick(now: t0.addingTimeInterval(4))
        #expect(engine.phase == .countingDown)
        #expect(abs(engine.timeRemaining - 6) < 0.001)

        engine.tick(now: t0.addingTimeInterval(10))
        #expect(engine.phase == .running)
        #expect(engine.completedReps == 0)
        #expect(chimes == 1)
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
        #expect(engine.completedReps == 0)
    }

    @Test func completingAllRepsFinishesWorkout() {
        let engine = makeEngine(reps: 2, secondsPerRep: 10, countdown: 5)
        var chimes = 0
        var finished = 0
        engine.onChime = { chimes += 1 }
        engine.onFinish = { finished += 1 }

        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        engine.start(now: t0)
        engine.tick(now: t0.addingTimeInterval(5))  // rep 1 begins
        engine.tick(now: t0.addingTimeInterval(15)) // rep 2 begins
        #expect(engine.completedReps == 1)
        engine.tick(now: t0.addingTimeInterval(25)) // rep 2 done

        #expect(engine.phase == .finished)
        #expect(engine.completedReps == 2)
        #expect(chimes == 2)
        #expect(finished == 1)
    }

    @Test func batchesChimeInGroupsAndShrinkTheFinalBatch() {
        // 7 reps in batches of 3 at 10s/rep: intervals of 30s, 30s, then a
        // final 10s single so the total still lands at 70s.
        let engine = makeEngine(reps: 7, secondsPerRep: 10, countdown: 5, repsPerChime: 3)
        var chimes = 0
        engine.onChime = { chimes += 1 }

        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        engine.start(now: t0)
        engine.tick(now: t0.addingTimeInterval(5))  // batch 1 begins
        #expect(engine.repsThisChime == 3)
        #expect(abs(engine.timeRemaining - 30) < 0.001)

        engine.tick(now: t0.addingTimeInterval(35)) // batch 2 begins
        #expect(engine.completedReps == 3)

        engine.tick(now: t0.addingTimeInterval(65)) // final single begins
        #expect(engine.completedReps == 6)
        #expect(engine.repsThisChime == 1)
        #expect(abs(engine.timeRemaining - 10) < 0.001)

        engine.tick(now: t0.addingTimeInterval(75)) // done
        #expect(engine.phase == .finished)
        #expect(engine.completedReps == 7)
        #expect(chimes == 3)
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

    private func makeWorkout(completedReps: Int = 47, type: BurpeeType = .tenCount) -> Workout {
        Workout(
            date: Date(timeIntervalSince1970: 1_752_000_000), // whole seconds: survives ISO 8601 round-trip
            burpeeType: type,
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

    @Test func lastWorkoutOfTypeReturnsMostRecentOfThatType() {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = WorkoutStore(fileURL: url)
        store.add(makeWorkout(completedReps: 10, type: .sixCount))
        store.add(makeWorkout(completedReps: 20, type: .tenCount))
        store.add(makeWorkout(completedReps: 30, type: .sixCount))

        #expect(store.lastWorkout(of: .sixCount)?.completedReps == 30)
        #expect(store.lastWorkout(of: .tenCount)?.completedReps == 20)
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

    @Test func savesMirrorIntoBackup() {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let backup = InMemoryBackup()

        let store = WorkoutStore(fileURL: url, backup: backup)
        store.add(makeWorkout())
        #expect(backup.data != nil)
    }

    @Test func restoresFromBackupWhenFileIsMissing() {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let backup = InMemoryBackup()

        let store = WorkoutStore(fileURL: url, backup: backup)
        store.add(makeWorkout(completedReps: 47))

        // Simulate app deletion: the sandbox file is gone, the backup is not.
        try? FileManager.default.removeItem(at: url)
        let reinstalled = WorkoutStore(fileURL: temporaryStoreURL(), backup: backup)
        #expect(reinstalled.workouts.map(\.completedReps) == [47])
    }

    @Test func fileWinsOverBackupWhenBothExist() {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let backup = InMemoryBackup()

        WorkoutStore(fileURL: url, backup: backup).add(makeWorkout(completedReps: 1))
        // The file moves on without the backup (e.g. backup written by an
        // older run): the local file is the source of truth.
        WorkoutStore(fileURL: url).add(makeWorkout(completedReps: 2))

        let store = WorkoutStore(fileURL: url, backup: backup)
        #expect(store.workouts.map(\.completedReps) == [2, 1])
    }

    @Test func keychainBackupRoundTrips() {
        let backup = KeychainBackup(
            service: "busy-timer-tests",
            account: "round-trip-\(UUID().uuidString)"
        )
        let payload = Data("workout-history-test".utf8)
        backup.write(payload)
        #expect(backup.read() == payload)

        let updated = Data("workout-history-test-2".utf8)
        backup.write(updated)
        #expect(backup.read() == updated)
    }
}

/// Test double for `HistoryBackup`.
private final class InMemoryBackup: HistoryBackup {
    var data: Data?
    func read() -> Data? { data }
    func write(_ data: Data) { self.data = data }
}
