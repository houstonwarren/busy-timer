import Foundation
import Observation

// MARK: - Daily history

/// Completed reps on one local calendar day, kept separate by burpee type.
struct WorkoutDay: Identifiable {
    let date: Date
    let repsByType: [BurpeeType: Int]

    var id: Date { date }

    /// Return zero for a type without a workout: an empty day and 10-count -> 0.
    func completedReps(of type: BurpeeType) -> Int {
        repsByType[type, default: 0]
    }
}

// MARK: - Workout storage

/// Holds workout history and persists it as JSON in Application Support.
/// An optional `HistoryBackup` mirrors every save outside the app sandbox
/// and is restored from when the file is missing (fresh install after the
/// app was deleted).
@MainActor
@Observable
final class WorkoutStore {
    private(set) var workouts: [Workout] = []

    private let fileURL: URL
    private let backup: HistoryBackup?

    init(fileURL: URL = WorkoutStore.defaultFileURL, backup: HistoryBackup? = nil) {
        self.fileURL = fileURL
        self.backup = backup
        load()
    }

    func add(_ workout: Workout) {
        workouts.insert(workout, at: 0)
        save()
    }

    func delete(atOffsets offsets: IndexSet) {
        workouts.remove(atOffsets: offsets)
        save()
    }

    /// Sum earned reps of one type: 6-count 40 + 10-count 20, asking for 6-count -> 40.
    func totalCompletedReps(of type: BurpeeType) -> Int {
        workouts.filter { $0.burpeeType == type }.reduce(0) { $0 + $1.completedReps }
    }

    /// Combine same-day workouts by type, ordered from oldest to newest.
    var dailyHistory: [WorkoutDay] {
        Dictionary(grouping: workouts) { Calendar.current.startOfDay(for: $0.date) }
            .map { date, workouts in
                WorkoutDay(
                    date: date,
                    repsByType: workouts.reduce(into: [:]) { totals, workout in
                        totals[workout.burpeeType, default: 0] += workout.completedReps
                    })
            }
            .sorted { $0.date < $1.date }
    }

    /// Most recent workout of the given type; seeds the next workout's target.
    func lastWorkout(of type: BurpeeType) -> Workout? {
        workouts.first { $0.burpeeType == type }
    }

    // MARK: - Persistence

    nonisolated static var defaultFileURL: URL {
        URL.applicationSupportDirectory.appending(path: "workouts.json")
    }

    private func load() {
        if let data = try? Data(contentsOf: fileURL) {
            workouts = decode(data) ?? []
        } else if let data = backup?.read(), let restored = decode(data) {
            // No local file (fresh install) but a backup exists: restore it
            // and re-materialize the local file.
            workouts = restored
            save()
        }
    }

    private func decode(_ data: Data) -> [Workout]? {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([Workout].self, from: data)
        } catch {
            assertionFailure("Failed to decode workout history: \(error)")
            return nil
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(workouts)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
            backup?.write(data)
        } catch {
            assertionFailure("Failed to save workout history: \(error)")
        }
    }
}
