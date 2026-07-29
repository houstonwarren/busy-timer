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
    @FocusState private var repsFocused: Bool

    init(plan: WorkoutPlan, promptedReps: Int, onComplete: @escaping (Int?) -> Void) {
        self.plan = plan
        self.promptedReps = promptedReps
        self.onComplete = onComplete
        _completedReps = State(initialValue: promptedReps)
    }

    private var finishedAll: Bool { promptedReps >= plan.targetReps }

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Theme.ink.opacity(0.15))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill((finishedAll ? Theme.pine : Theme.clay).opacity(0.12))
                        .frame(width: 84, height: 84)
                    Image(systemName: finishedAll ? "checkmark" : "flag.checkered")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(finishedAll ? Theme.pine : Theme.clay)
                }

                Text(finishedAll ? "Workout Complete" : "Stopped Early")
                    .font(Theme.display(28))
                    .foregroundStyle(Theme.ink)

                Text("Timer prompted \(promptedReps) of \(plan.targetReps) \(plan.burpeeType.rawValue) burpees")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            VStack(spacing: 14) {
                Text("How many did you actually do?")
                    .overline()

                HStack(spacing: 24) {
                    AdjustButton(systemImage: "minus") {
                        completedReps = max(0, completedReps - 1)
                    }

                    TextField("0", value: $completedReps, format: .number)
                        .keyboardType(.numberPad)
                        .focused($repsFocused)
                        .font(Theme.display(52))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .tint(Theme.pine)
                        .frame(width: 130)

                    AdjustButton(systemImage: "plus") {
                        completedReps = min(999, completedReps + 1)
                    }
                }
            }
            .card()
            .padding(.horizontal, 20)

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                Button("Save workout") {
                    repsFocused = false
                    onComplete(completedReps)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Discard") {
                    onComplete(nil)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.rust)
                .padding(.vertical, 12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .paperBackground()
        .presentationDetents([.large])
        .presentationBackground(Theme.paper)
        .presentationDragIndicator(.hidden)
    }
}

#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        WorkoutSummaryView(
            plan: WorkoutPlan(targetReps: 50, burpeeType: .sixCount, totalDuration: 1200),
            promptedReps: 32
        ) { _ in }
    }
}
