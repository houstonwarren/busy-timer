import Foundation

enum BurpeeType: String, Codable, CaseIterable, Identifiable {
    case sixCount = "6-count"
    case tenCount = "10-count"

    var id: String { rawValue }
}

/// The parameters for a workout about to be performed. Duration is fixed at
/// twenty minutes — the whole idea of the app — so the only choices are the
/// target, the burpee style, and how many reps each chime asks for.
struct WorkoutPlan: Hashable {
    var targetReps: Int
    var burpeeType: BurpeeType
    var repsPerChime: Int = 1
    var totalDuration: TimeInterval = 20 * 60

    var secondsPerRep: TimeInterval {
        totalDuration / Double(targetReps)
    }

    /// Interval between chimes for a full batch (the final batch may be
    /// shorter if the target isn't divisible by `repsPerChime`).
    var secondsPerChime: TimeInterval {
        secondsPerRep * Double(min(repsPerChime, targetReps))
    }
}

/// A finished workout as recorded in history.
struct Workout: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let burpeeType: BurpeeType
    let targetReps: Int
    let completedReps: Int
    let secondsPerRep: TimeInterval

    init(
        id: UUID = UUID(),
        date: Date = .now,
        burpeeType: BurpeeType,
        targetReps: Int,
        completedReps: Int,
        secondsPerRep: TimeInterval
    ) {
        self.id = id
        self.date = date
        self.burpeeType = burpeeType
        self.targetReps = targetReps
        self.completedReps = completedReps
        self.secondsPerRep = secondsPerRep
    }

    var completionFraction: Double {
        guard targetReps > 0 else { return 0 }
        return Double(completedReps) / Double(targetReps)
    }
}
