import SwiftUI

struct ContentView: View {
    @Environment(WorkoutStore.self) private var workoutStore

    @State private var targetReps: Int?
    @State private var burpeeType: BurpeeType = .sixCount
    @State private var repsPerChime = 1
    @State private var activePlan: WorkoutPlan?
    @FocusState private var repsFocused: Bool

    private let batchChoices = [1, 2, 3, 4, 5]

    private var lastWorkout: Workout? {
        workoutStore.lastWorkout(of: burpeeType)
    }

    private var draftPlan: WorkoutPlan? {
        guard let targetReps, targetReps > 0 else { return nil }
        return WorkoutPlan(
            targetReps: targetReps,
            burpeeType: burpeeType,
            repsPerChime: repsPerChime
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    brief
                    targetSection
                    typeSection
                    batchSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            // no panning when everything already fits on screen
            .scrollBounceBehavior(.basedOnSize)
            // simultaneous so buttons keep every tap; any touch still drops the keyboard
            .simultaneousGesture(TapGesture().onEnded {
                if repsFocused { repsFocused = false }
            })
            .paperBackground()
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    paceRow
                    Button("start workout") {
                        repsFocused = false
                        activePlan = draftPlan
                    }
                    .buttonStyle(InkBarButtonStyle(showDot: true))
                    .disabled(draftPlan == nil)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 10)
                .background(Theme.paper.opacity(0.94))
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { repsFocused = false }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $activePlan) { plan in
                TimerView(plan: plan)
            }
        }
        .tint(Theme.ink)
        .onAppear { prefillFromHistory() }
        .onChange(of: burpeeType) { prefillFromHistory() }
    }

    /// Seed the target with what the user actually did last time on this
    /// burpee type; leave the field blank when there's no history.
    private func prefillFromHistory() {
        if let last = lastWorkout, last.completedReps > 0 {
            targetReps = last.completedReps
        } else {
            targetReps = nil
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 0) {
                Text("busy timer")
                    .font(Theme.display(21))
                    .foregroundStyle(Theme.ink)
                Text(".")
                    .font(Theme.display(21))
                    .foregroundStyle(Theme.red)
            }
            Spacer()
            NavigationLink {
                HistoryView()
            } label: {
                Image(systemName: "clock")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 36, height: 36)
                    .border(Theme.ink, width: 1.5)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 10)
    }

    /// The whole pitch in one small strip — same size on every visit.
    private var brief: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.red)
                    .frame(width: 48, height: 48)
                VStack(spacing: 0) {
                    Text("20")
                        .font(Theme.display(17))
                    Text("MIN")
                        .font(.system(size: 7, weight: .semibold))
                        .kerning(1.5)
                }
                .foregroundStyle(Theme.paper)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    Text("just burpees")
                        .font(Theme.display(16))
                        .foregroundStyle(Theme.ink)
                    Text(".")
                        .font(Theme.display(16))
                        .foregroundStyle(Theme.red)
                }
                Text("four times a week, forever.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.grey)
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 24)
    }

    private var targetSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rule()
            HStack {
                Text("target reps").label()
                Spacer()
                if let last = lastWorkout {
                    Text("last \(last.completedReps)").label(color: Theme.grey)
                }
            }
            .padding(.top, 14)
            HStack(spacing: 16) {
                SquareStepButton(text: "−") {
                    let next = (targetReps ?? 0) - 1
                    targetReps = next > 0 ? next : nil
                }
                TextField("0", value: $targetReps, format: .number)
                    .keyboardType(.numberPad)
                    .focused($repsFocused)
                    .simultaneousGesture(TapGesture().onEnded { targetReps = nil })
                    .font(Theme.display(84))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .tint(Theme.red)
                SquareStepButton(text: "+") {
                    targetReps = min(999, (targetReps ?? 0) + 1)
                }
            }
            .padding(.top, 4)
        }
        .padding(.bottom, 24)
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rule()
            Text("burpee type")
                .label()
                .padding(.top, 14)
            SegmentedBox(items: BurpeeType.allCases, selection: $burpeeType) { $0.rawValue }
                .padding(.top, 12)
        }
        .padding(.bottom, 24)
    }

    private var batchSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rule()
            Text("reps per set")
                .label()
                .padding(.top, 14)
            SegmentedBox(items: batchChoices, selection: $repsPerChime) { "\($0)" }
                .padding(.top, 12)
        }
        .padding(.bottom, 24)
    }

    /// The workout's cadence, spelled out above the start button. Red is the
    /// time number; everything else stays ink.
    private var paceRow: some View {
        VStack(spacing: 0) {
            Rule()
            HStack(alignment: .firstTextBaseline) {
                Text("your pace").label()
                Spacer()
                if let plan = draftPlan {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(plan.repsPerChime)")
                            .font(Theme.display(22))
                            .foregroundStyle(Theme.ink)
                        Text(plan.repsPerChime == 1 ? "rep every" : "reps every")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.ink)
                        Text("\(plan.secondsPerChime, format: .number.precision(.fractionLength(1)))s")
                            .font(Theme.display(22))
                            .foregroundStyle(Theme.red)
                    }
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.2), value: plan)
                } else {
                    Text("set a target").label(color: Theme.grey)
                }
            }
            .padding(.vertical, 13)
        }
    }
}

#Preview {
    ContentView()
        .environment(WorkoutStore(fileURL: URL.temporaryDirectory.appending(path: "preview-workouts.json")))
}
