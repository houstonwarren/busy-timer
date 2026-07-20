import Foundation

enum BurpeeType: String, Codable, CaseIterable, Identifiable {
    case sixCount = "6-count"
    case tenCount = "10-count"

    var id: String { rawValue }
}

/// The parameters for a workout about to be performed.
struct WorkoutPlan: Hashable {
    var targetReps: Int
    var burpeeType: BurpeeType
    var totalDuration: TimeInterval

    var secondsPerRep: TimeInterval {
        totalDuration / Double(targetReps)
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
