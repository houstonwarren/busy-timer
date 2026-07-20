import SwiftUI

/// Shown when a workout ends (completed or stopped early). Lets the user
/// record how many burpees they actually performed before saving to history.
struct WorkoutSummaryView: View {
    let plan: WorkoutPlan
    /// Reps the timer prompted for — the starting point for the user's answer.
    let promptedReps: Int
    /// Called with the confirmed rep count, or `nil` if the user discards.
    let onComplete: (Int?) -> Void

    @State private var completedReps: Int

    init(plan: WorkoutPlan, promptedReps: Int, onComplete: @escaping (Int?) -> Void) {
        self.plan = plan
        self.promptedReps = promptedReps
        self.onComplete = onComplete
        _completedReps = State(initialValue: promptedReps)
    }

    private var finishedAll: Bool { promptedReps >= plan.targetReps }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: finishedAll ? "trophy.fill" : "flag.checkered")
                            .font(.system(size: 44))
                            .foregroundStyle(finishedAll ? .yellow : .secondary)
                        Text(finishedAll ? "Workout complete!" : "Stopped early")
                            .font(.title2.weight(.semibold))
                        Text("Timer prompted \(promptedReps) of \(plan.targetReps) \(plan.burpeeType.rawValue) burpees")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section("How many did you actually do?") {
                    Stepper(value: $completedReps, in: 0...999) {
                        TextField("Reps", value: $completedReps, format: .number)
                            .keyboardType(.numberPad)
                            .font(.title3.weight(.semibold))
                    }
                }

                Section {
                    Button {
                        onComplete(completedReps)
                    } label: {
                        Label("Save Workout", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    Button("Discard", role: .destructive) {
                        onComplete(nil)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    WorkoutSummaryView(
        plan: WorkoutPlan(targetReps: 50, burpeeType: .sixCount, totalDuration: 1200),
        promptedReps: 32
    ) { _ in }
}
