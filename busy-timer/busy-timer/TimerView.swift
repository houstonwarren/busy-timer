import SwiftUI

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

    /// Color of the live ring and its glow for the current phase.
    private var ringColor: Color {
        if engine.phase == .paused { return .white.opacity(0.35) }
        return engine.isCountingDown ? Theme.amber : Theme.volt
    }

    var body: some View {
        VStack(spacing: 0) {
            statusHeader
                .padding(.top, 8)

            Spacer()

            intervalRing

            Spacer()

            repProgress
                .padding(.horizontal, 36)
                .padding(.bottom, 28)

            controls
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .inkBackground()
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Theme.ink, for: .navigationBar)
        .onAppear {
            engine.onRepStart = { chimePlayer.play() }
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
                    .overline(color: Theme.volt)
            case .countingDown:
                Text("Get Ready")
                    .overline(color: Theme.amber)
            case .running:
                Text("Working")
                    .overline(color: Theme.volt)
            case .paused:
                Text("Paused")
                    .overline(color: Theme.textSecondary)
            case .finished:
                Text("Done")
                    .overline(color: Theme.volt)
            }

            Text("\(plan.targetReps) × \(plan.burpeeType.rawValue) · \(plan.secondsPerRep, format: .number.precision(.fractionLength(1)))s/rep")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
                .monospacedDigit()
        }
    }

    private var intervalRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 16)

            Circle()
                .trim(from: 0, to: engine.phase == .ready ? 1 : engine.intervalFractionRemaining)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: ringColor.opacity(0.45), radius: 18)
                .animation(.linear(duration: 0.05), value: engine.intervalFractionRemaining)
                .animation(.easeOut(duration: 0.3), value: ringColor)

            VStack(spacing: 6) {
                if engine.phase == .ready {
                    Text("\(plan.targetReps)")
                        .font(Theme.display(72))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text("reps to go")
                        .overline()
                } else {
                    Text(engine.timeRemaining, format: .number.precision(.fractionLength(1)))
                        .font(Theme.display(76))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                    Text(engine.isCountingDown ? "starting in" : "seconds")
                        .overline()
                }
            }
        }
        .frame(width: 290, height: 290)
        .padding(.horizontal)
    }

    private var repProgress: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Rep")
                    .overline()
                Spacer()
                HStack(spacing: 2) {
                    Text("\(engine.currentRep)")
                        .font(Theme.display(22))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text(" / \(plan.targetReps)")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(Theme.volt)
                        .frame(
                            width: max(
                                0,
                                geo.size.width * Double(engine.completedReps) / Double(max(plan.targetReps, 1))
                            )
                        )
                        .animation(.easeOut(duration: 0.3), value: engine.completedReps)
                }
            }
            .frame(height: 6)
        }
        .opacity(engine.phase == .ready ? 0 : 1)
        .animation(.easeOut(duration: 0.25), value: engine.phase)
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
                .buttonStyle(VoltButtonStyle())

            case .countingDown, .running, .paused:
                Button("Stop") {
                    if engine.isCountingDown {
                        // Nothing performed yet — no summary to record.
                        dismiss()
                    } else {
                        engine.stop()
                    }
                }
                .buttonStyle(GhostButtonStyle(tint: Theme.coral))

                if engine.phase == .paused {
                    Button("Resume") {
                        engine.resume()
                    }
                    .buttonStyle(VoltButtonStyle())
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
        TimerView(plan: WorkoutPlan(targetReps: 10, burpeeType: .sixCount, totalDuration: 120))
    }
    .environment(WorkoutStore(fileURL: URL.temporaryDirectory.appending(path: "preview-workouts.json")))
}
