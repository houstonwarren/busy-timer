import SwiftUI

struct HistoryView: View {
    @Environment(WorkoutStore.self) private var workoutStore

    var body: some View {
        Group {
            if workoutStore.workouts.isEmpty {
                ContentUnavailableView(
                    "No workouts yet",
                    systemImage: "figure.strengthtraining.functional",
                    description: Text("Finish a workout and it will show up here.")
                )
            } else {
                List {
                    Section {
                        LabeledContent("Workouts", value: "\(workoutStore.workouts.count)")
                        LabeledContent("Total burpees", value: "\(workoutStore.totalCompletedReps)")
                    }

                    Section("Workouts") {
                        ForEach(workoutStore.workouts) { workout in
                            WorkoutRow(workout: workout)
                        }
                        .onDelete { offsets in
                            workoutStore.delete(atOffsets: offsets)
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
    }
}

private struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.date, format: .dateTime.month().day().year().hour().minute())
                    .font(.headline)
                Text("\(workout.burpeeType.rawValue) · \(workout.secondsPerRep, format: .number.precision(.fractionLength(1)))s/rep")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(workout.completedReps) / \(workout.targetReps)")
                    .font(.headline)
                    .monospacedDigit()
                Text(workout.completionFraction, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline)
                    .foregroundStyle(workout.completedReps >= workout.targetReps ? .green : .secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .environment(WorkoutStore(fileURL: URL.temporaryDirectory.appending(path: "preview-workouts.json")))
}
