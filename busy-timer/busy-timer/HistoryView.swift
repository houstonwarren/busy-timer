import SwiftUI

struct HistoryView: View {
    @Environment(WorkoutStore.self) private var workoutStore

    var body: some View {
        Group {
            if workoutStore.workouts.isEmpty {
                emptyState
            } else {
                List {
                    statTiles
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 12, trailing: 20))

                    Section {
                        ForEach(workoutStore.workouts) { workout in
                            WorkoutRow(workout: workout)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                        }
                        .onDelete { offsets in
                            workoutStore.delete(atOffsets: offsets)
                        }
                    } header: {
                        Text("Workouts")
                            .overline()
                            .padding(.leading, 4)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .inkBackground()
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.ink, for: .navigationBar)
    }

    private var statTiles: some View {
        HStack(spacing: 12) {
            StatTile(value: "\(workoutStore.workouts.count)", label: "Workouts")
            StatTile(value: "\(workoutStore.totalCompletedReps)", label: "Total Burpees")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.strengthtraining.functional")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(Theme.volt)
            Text("No workouts yet")
                .font(Theme.display(24))
                .foregroundStyle(.white)
            Text("Finish a workout and it will show up here.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(Theme.display(32))
                .monospacedDigit()
                .foregroundStyle(Theme.volt)
            Text(label)
                .overline()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16)
    }
}

private struct WorkoutRow: View {
    let workout: Workout

    private var hitTarget: Bool { workout.completedReps >= workout.targetReps }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.date, format: .dateTime.month().day().year())
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                    Text("\(workout.burpeeType.rawValue) · \(workout.secondsPerRep, format: .number.precision(.fractionLength(1)))s/rep")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(workout.completedReps)")
                        .font(Theme.display(24))
                        .foregroundStyle(hitTarget ? Theme.volt : .white)
                    Text("/ \(workout.targetReps)")
                        .font(.system(.footnote, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(hitTarget ? Theme.volt : Theme.amber)
                        .frame(width: geo.size.width * min(1, workout.completionFraction))
                }
            }
            .frame(height: 4)
        }
        .card(padding: 16)
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .environment(WorkoutStore(fileURL: URL.temporaryDirectory.appending(path: "preview-workouts.json")))
}
