import SwiftUI

struct ContentView: View {
    @Environment(WorkoutStore.self) private var workoutStore

    @State private var targetReps: Int?
    @State private var burpeeType: BurpeeType = .sixCount
    @State private var durationMinutes = 20
    @State private var activePlan: WorkoutPlan?
    @FocusState private var repsFocused: Bool

    private let durationChoices = [10, 15, 20, 25, 30]

    private var draftPlan: WorkoutPlan? {
        guard let targetReps, targetReps > 0 else { return nil }
        return WorkoutPlan(
            targetReps: targetReps,
            burpeeType: burpeeType,
            totalDuration: TimeInterval(durationMinutes * 60)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    targetCard
                    typeCard
                    durationCard
                    paceCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .inkBackground()
            .safeAreaInset(edge: .bottom) {
                Button {
                    repsFocused = false
                    activePlan = draftPlan
                } label: {
                    Text("Start Workout")
                }
                .buttonStyle(VoltButtonStyle())
                .disabled(draftPlan == nil)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .background(Theme.ink.opacity(0.9))
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { repsFocused = false }
                        .fontWeight(.semibold)
                }
            }
            .toolbarBackground(Theme.ink, for: .navigationBar)
            .navigationDestination(item: $activePlan) { plan in
                TimerView(plan: plan)
            }
        }
        .tint(Theme.volt)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Busy Timer")
                .overline(color: Theme.volt)
            Text("Burpees,\non the clock.")
                .font(Theme.display(38))
                .foregroundStyle(.white)
                .lineSpacing(2)
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var targetCard: some View {
        VStack(spacing: 12) {
            Text("Target Reps")
                .overline()
            TextField("0", value: $targetReps, format: .number)
                .keyboardType(.numberPad)
                .focused($repsFocused)
                .font(Theme.display(64))
                .monospacedDigit()
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .tint(Theme.volt)
        }
        .card()
        .contentShape(Rectangle())
        .onTapGesture { repsFocused = true }
    }

    private var typeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Burpee Type")
                .overline()
            HStack(spacing: 6) {
                ForEach(BurpeeType.allCases) { type in
                    ChoiceChip(title: type.rawValue, isSelected: burpeeType == type) {
                        burpeeType = type
                    }
                }
            }
        }
        .card(padding: 16)
    }

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Duration")
                .overline()
            HStack(spacing: 6) {
                ForEach(durationChoices, id: \.self) { minutes in
                    ChoiceChip(title: "\(minutes)", isSelected: durationMinutes == minutes) {
                        durationMinutes = minutes
                    }
                }
            }
            Text("Minutes")
                .font(.caption2)
                .foregroundStyle(Theme.textFaint)
        }
        .card(padding: 16)
    }

    private var paceCard: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your Pace")
                    .overline()
                if let plan = draftPlan {
                    Text("One rep every chime, \(plan.targetReps) chimes in \(durationMinutes) min.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Text("Enter a target to see your pace.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textFaint)
                }
            }
            Spacer()
            if let plan = draftPlan {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(plan.secondsPerRep, format: .number.precision(.fractionLength(1)))
                        .font(Theme.display(34))
                        .monospacedDigit()
                        .foregroundStyle(Theme.volt)
                        .contentTransition(.numericText())
                    Text("s/rep")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .card(padding: 16)
        .animation(.easeOut(duration: 0.2), value: draftPlan)
    }
}

#Preview {
    ContentView()
        .environment(WorkoutStore(fileURL: URL.temporaryDirectory.appending(path: "preview-workouts.json")))
}
