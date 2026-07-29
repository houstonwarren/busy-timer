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
        .paperBackground()
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.paper, for: .navigationBar)
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
                .foregroundStyle(Theme.pine)
            Text("Nothing yet")
                .font(Theme.display(26))
                .foregroundStyle(Theme.ink)
            Text("Your first twenty minutes will land here.")
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
                .foregroundStyle(Theme.pine)
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
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text("\(workout.burpeeType.rawValue) · \(workout.secondsPerRep, format: .number.precision(.fractionLength(1)))s/rep")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(workout.completedReps)")
                        .font(Theme.display(24))
                        .foregroundStyle(hitTarget ? Theme.pine : Theme.ink)
                    Text("/ \(workout.targetReps)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.ink.opacity(0.08))
                    Capsule()
                        .fill(hitTarget ? Theme.pine : Theme.clay)
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
