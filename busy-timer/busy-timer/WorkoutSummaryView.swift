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
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    StatusWord(word: finishedAll ? "done" : "stopped early")
                    Spacer()
                    Text("prompted \(promptedReps) of \(plan.targetReps) · \(plan.burpeeType.rawValue)")
                        .font(.system(size: 10, weight: .semibold))
                        .kerning(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.grey)
                }
                Rule()
            }
            .padding(.top, 28)

            Text("how many did you actually do?")
                .label()
                .padding(.top, 28)

            HStack(spacing: 16) {
                SquareStepButton(text: "−") {
                    completedReps = max(0, completedReps - 1)
                }
                TextField("0", value: $completedReps, format: .number)
                    .keyboardType(.numberPad)
                    .focused($repsFocused)
                    .font(Theme.display(84))
                    .foregroundStyle(Theme.blue)
                    .multilineTextAlignment(.center)
                    .tint(Theme.red)
                SquareStepButton(text: "+") {
                    completedReps = min(999, completedReps + 1)
                }
            }
            .padding(.top, 8)

            Spacer(minLength: 0)

            Button("save workout") {
                repsFocused = false
                onComplete(completedReps)
            }
            .buttonStyle(InkBarButtonStyle(showDot: true))

            Button("discard") {
                onComplete(nil)
            }
            .buttonStyle(OutlineBarButtonStyle(tint: Theme.red))
            .padding(.top, 10)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .simultaneousGesture(TapGesture().onEnded {
            if repsFocused { repsFocused = false }
        })
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
