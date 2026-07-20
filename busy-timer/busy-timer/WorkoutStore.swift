import Foundation
import Observation

/// Holds workout history and persists it as JSON in Application Support.
@MainActor
@Observable
final class WorkoutStore {
    private(set) var workouts: [Workout] = []

    private let fileURL: URL

    init(fileURL: URL = WorkoutStore.defaultFileURL) {
        self.fileURL = fileURL
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

    var totalCompletedReps: Int {
        workouts.reduce(0) { $0 + $1.completedReps }
    }

    // MARK: - Persistence

    nonisolated static var defaultFileURL: URL {
        URL.applicationSupportDirectory.appending(path: "workouts.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            workouts = try decoder.decode([Workout].self, from: data)
        } catch {
            assertionFailure("Failed to decode workout history: \(error)")
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
        } catch {
            assertionFailure("Failed to save workout history: \(error)")
        }
    }
}
