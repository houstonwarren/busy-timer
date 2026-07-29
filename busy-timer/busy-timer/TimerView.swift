import SwiftUI

/// The live workout screen. Built to be read from the floor: the phone lies
/// flat while the user stands, so the two things that matter — the chime
/// countdown and the reps done — are giant numerals stacked down the middle,
/// nothing tucked in corners.
struct TimerView: View {
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(\.dismiss) private var dismiss

    let plan: WorkoutPlan

    @State private var engine: WorkoutEngine
    @State private var chimePlayer = ChimePlayer()
    @State private var showSummary = false

    init(plan: WorkoutPlan) {
        self.plan = plan
        _engine = State(initialValue: WorkoutEngine(plan: plan))
    }

    private var accent: Color {
        if engine.phase == .paused { return Theme.textFaint }
        return engine.isCountingDown ? Theme.clay : Theme.pine
    }

    /// Whole seconds left in the interval, rounded up so it never shows 0 early.
    private var wholeSecondsRemaining: Int {
        Int(engine.timeRemaining.rounded(.up))
    }

    var body: some View {
        VStack(spacing: 0) {
            statusHeader
                .padding(.top, 8)

            Spacer()

            timerBlock

            Spacer()

            repBlock

            Spacer()

            controls
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .paperBackground()
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Theme.paper, for: .navigationBar)
        .onAppear {
            engine.onChime = { chimePlayer.play() }
        }
        .onChange(of: engine.phase) { _, newPhase in
            UIApplication.shared.isIdleTimerDisabled =
                newPhase == .running || newPhase == .countingDown
            if newPhase == .finished {
                showSummary = true
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sheet(isPresented: $showSummary) {
            WorkoutSummaryView(plan: plan, promptedReps: engine.completedReps) { completedReps in
                if let completedReps {
                    workoutStore.add(
                        Workout(
                            burpeeType: plan.burpeeType,
                            targetReps: plan.targetReps,
                            completedReps: completedReps,
                            secondsPerRep: plan.secondsPerRep
                        )
                    )
                }
                showSummary = false
                dismiss()
            }
            .interactiveDismissDisabled()
        }
    }

    private var statusHeader: some View {
        VStack(spacing: 6) {
            switch engine.phase {
            case .ready:
                Text("Ready")
                    .overline(color: Theme.pine)
            case .countingDown:
                Text("Get Ready")
                    .overline(color: Theme.clay)
            case .running:
                Text("Working")
                    .overline(color: Theme.pine)
            case .paused:
                Text("Paused")
                    .overline(color: Theme.textSecondary)
            case .finished:
                Text("Done")
                    .overline(color: Theme.pine)
            }

            Text("\(plan.targetReps) × \(plan.burpeeType.rawValue) · \(plan.repsPerChime) per chime · every \(plan.secondsPerChime, format: .number.precision(.fractionLength(0)))s")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
                .monospacedDigit()
        }
    }

    /// Chime countdown: giant seconds over a slim progress bar.
    private var timerBlock: some View {
        VStack(spacing: 10) {
            if engine.phase == .ready {
                Text(Duration.seconds(plan.totalDuration), format: .time(pattern: .minuteSecond))
                    .font(Theme.display(88))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Text("on the clock")
                    .overline()
            } else {
                Text("\(wholeSecondsRemaining)")
                    .font(Theme.display(96))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.linear(duration: 0.1), value: wholeSecondsRemaining)
                Text(engine.isCountingDown ? "starting in" : "next chime")
                    .overline()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.ink.opacity(0.08))
                    Capsule()
                        .fill(accent)
                        .frame(
                            width: geo.size.width * (engine.phase == .ready ? 1 : engine.intervalFractionRemaining)
                        )
                        .animation(.linear(duration: 0.05), value: engine.intervalFractionRemaining)
                        .animation(.easeOut(duration: 0.3), value: accent)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 56)
            .padding(.top, 6)
        }
    }

    /// Reps done: the biggest number on screen.
    private var repBlock: some View {
        VStack(spacing: 4) {
            if engine.phase == .ready {
                Text("\(plan.targetReps)")
                    .font(Theme.display(120))
                    .monospacedDigit()
                    .foregroundStyle(Theme.pine)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("reps ahead")
                    .overline()
            } else {
                Text("\(engine.completedReps)")
                    .font(Theme.display(132))
                    .monospacedDigit()
                    .foregroundStyle(engine.phase == .paused ? Theme.textFaint : Theme.pine)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.3), value: engine.completedReps)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("of \(plan.targetReps) done")
                    .overline(color: Theme.textSecondary)
            }
        }
        .padding(.horizontal, 24)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            switch engine.phase {
            case .ready:
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(GhostButtonStyle(tint: Theme.textSecondary))

                Button("Start") {
                    engine.start()
                }
                .buttonStyle(PrimaryButtonStyle())

            case .countingDown, .running, .paused:
                Button("Stop") {
                    if engine.isCountingDown {
                        // Nothing performed yet — no summary to record.
                        dismiss()
                    } else {
                        engine.stop()
                    }
                }
                .buttonStyle(GhostButtonStyle(tint: Theme.rust))

                if engine.phase == .paused {
                    Button("Resume") {
                        engine.resume()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Pause") {
                        engine.pause()
                    }
                    .buttonStyle(GhostButtonStyle())
                }

            case .finished:
                EmptyView()
            }
        }
    }
}

#Preview {
    NavigationStack {
        TimerView(plan: WorkoutPlan(targetReps: 10, burpeeType: .sixCount, repsPerChime: 3, totalDuration: 120))
    }
    .environment(WorkoutStore(fileURL: URL.temporaryDirectory.appending(path: "preview-workouts.json")))
}
