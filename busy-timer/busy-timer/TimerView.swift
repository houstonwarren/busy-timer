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

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            intervalRing

            VStack(spacing: 8) {
                if engine.phase == .ready {
                    Text("\(plan.targetReps) \(plan.burpeeType.rawValue) burpees")
                        .font(.title2.weight(.semibold))
                    Text("\(plan.secondsPerRep, format: .number.precision(.fractionLength(1)))s per rep")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Rep \(engine.currentRep) of \(plan.targetReps)")
                        .font(.title2.weight(.semibold))
                        .contentTransition(.numericText())

                    ProgressView(value: Double(engine.completedReps), total: Double(plan.targetReps))
                        .padding(.horizontal, 60)
                }
            }

            Spacer()

            controls
                .padding(.bottom, 24)
        }
        .navigationBarBackButtonHidden(true)
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

    private var intervalRing: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 14)

            Circle()
                .trim(from: 0, to: engine.intervalFractionRemaining)
                .stroke(
                    engine.isCountingDown ? Color.orange : Color.accentColor,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.05), value: engine.intervalFractionRemaining)

            VStack(spacing: 4) {
                if engine.phase == .ready {
                    Text("Ready")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                } else {
                    Text(engine.timeRemaining, format: .number.precision(.fractionLength(1)))
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(engine.isCountingDown ? "get ready" : "seconds")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 280, height: 280)
        .padding(.horizontal)
    }

    private var controls: some View {
        HStack(spacing: 16) {
            switch engine.phase {
            case .ready:
                Button {
                    engine.start()
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button(role: .cancel) {
                    dismiss()
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

            case .countingDown, .running, .paused:
                Button {
                    engine.phase == .paused ? engine.resume() : engine.pause()
                } label: {
                    Label(
                        engine.phase == .paused ? "Resume" : "Pause",
                        systemImage: engine.phase == .paused ? "play.fill" : "pause.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(engine.phase == .paused ? .green : .orange)

                Button(role: .destructive) {
                    if engine.isCountingDown {
                        // Nothing performed yet — no summary to record.
                        dismiss()
                    } else {
                        engine.stop()
                    }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

            case .finished:
                EmptyView()
            }
        }
        .controlSize(.large)
        .font(.headline)
        .padding(.horizontal, 32)
    }
}

#Preview {
    NavigationStack {
        TimerView(plan: WorkoutPlan(targetReps: 10, burpeeType: .sixCount, totalDuration: 120))
    }
    .environment(WorkoutStore(fileURL: URL.temporaryDirectory.appending(path: "preview-workouts.json")))
}
