import SwiftUI

struct HistoryView: View {
    @Environment(WorkoutStore.self) private var workoutStore

    var body: some View {
        Group {
            if workoutStore.workouts.isEmpty {
                emptyState
            } else {
                List {
                    statRow
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 18, trailing: 24))

                    ForEach(workoutStore.workouts) { workout in
                        WorkoutRow(workout: workout)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 18, trailing: 24))
                    }
                    .onDelete { offsets in
                        workoutStore.delete(atOffsets: offsets)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .paperBackground()
        .navigationTitle("history")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.paper, for: .navigationBar)
    }

    /// Lifetime numbers: blue for earned reps, ink for the rest.
    private var statRow: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(workoutStore.workouts.count)")
                        .font(Theme.display(40))
                        .foregroundStyle(Theme.ink)
                    Text("workouts").label(color: Theme.grey)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(workoutStore.totalCompletedReps)")
                        .font(Theme.display(40))
                        .foregroundStyle(Theme.blue)
                    Text("total burpees").label(color: Theme.grey)
                }
            }
            Rule()
                .padding(.top, 14)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            StatusWord(word: "nothing yet")
            Text("your first twenty minutes will land here.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.grey)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct WorkoutRow: View {
    let workout: Workout

    private var hitTarget: Bool { workout.completedReps >= workout.targetReps }

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(workout.date, format: .dateTime.month().day().year())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("\(workout.burpeeType.rawValue) · \(workout.secondsPerRep, format: .number.precision(.fractionLength(1)))s/rep")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.grey)
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(workout.completedReps)")
                        .font(Theme.display(24))
                        .foregroundStyle(hitTarget ? Theme.blue : Theme.ink)
                    Text("/\(workout.targetReps)")
                        .font(Theme.display(14))
                        .foregroundStyle(Theme.grey)
                }
            }

            // blue = reps done, as everywhere
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.track)
                    Rectangle()
                        .fill(Theme.blue)
                        .frame(width: geo.size.width * min(1, workout.completionFraction))
                }
            }
            .frame(height: 4)
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .environment(WorkoutStore(fileURL: URL.temporaryDirectory.appending(path: "preview-workouts.json")))
}
