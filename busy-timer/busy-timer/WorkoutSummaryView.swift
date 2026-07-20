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
                .fill(Color.white.opacity(0.15))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill((finishedAll ? Theme.volt : Theme.amber).opacity(0.12))
                        .frame(width: 84, height: 84)
                    Image(systemName: finishedAll ? "trophy.fill" : "flag.checkered")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(finishedAll ? Theme.volt : Theme.amber)
                }

                Text(finishedAll ? "Workout Complete" : "Stopped Early")
                    .font(Theme.display(26))
                    .foregroundStyle(.white)

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
                    RepAdjustButton(systemImage: "minus") {
                        completedReps = max(0, completedReps - 1)
                    }

                    TextField("0", value: $completedReps, format: .number)
                        .keyboardType(.numberPad)
                        .focused($repsFocused)
                        .font(Theme.display(52))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .tint(Theme.volt)
                        .frame(width: 130)

                    RepAdjustButton(systemImage: "plus") {
                        completedReps = min(999, completedReps + 1)
                    }
                }
            }
            .card()
            .padding(.horizontal, 20)

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                Button("Save Workout") {
                    repsFocused = false
                    onComplete(completedReps)
                }
                .buttonStyle(VoltButtonStyle())

                Button("Discard") {
                    onComplete(nil)
                }
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.coral)
                .padding(.vertical, 12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .inkBackground()
        .presentationDetents([.large])
        .presentationBackground(Theme.ink)
        .presentationDragIndicator(.hidden)
    }
}

private struct RepAdjustButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(Theme.surfaceBright)
                        .overlay(Circle().strokeBorder(Theme.cardStroke, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
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
