import SwiftUI

/// The live workout screen, read from the floor while standing: a giant
/// countdown on top, the red clock bar under it, then the dot grid — one dot
/// per rep, blue when done, red for the set the next chime asks for — and a
/// fixed-size counter row. Only the dots resize as targets grow.
struct TimerView: View {
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(\.dismiss) private var dismiss

    let plan: WorkoutPlan

    @State private var engine: WorkoutEngine
    @State private var chimePlayer = ChimePlayer()
    @State private var showSummary = false
    /// Set when the user backs out during the lead-in countdown: the engine
    /// still finishes, but there's nothing to record so no summary shows.
    @State private var cancelled = false

    init(plan: WorkoutPlan) {
        self.plan = plan
        _engine = State(initialValue: WorkoutEngine(plan: plan))
    }

    /// Seconds and tenths shown while running, floored so "26.4" reads
    /// literally: 26 whole seconds and 4 tenths left.
    private var wholeSecondsRemaining: Int {
        Int(engine.timeRemaining)
    }

    private var tenthsRemaining: Int {
        Int(engine.timeRemaining * 10) % 10
    }

    private var statusWord: String {
        switch engine.phase {
        case .ready: "ready"
        case .countingDown: "get ready"
        case .running: "working"
        case .paused: "paused"
        case .finished: "done"
        }
    }

    /// What the countdown is counting toward, in the user's terms.
    private var countdownLabel: String {
        if engine.phase == .ready { return "on the clock" }
        if engine.isCountingDown { return "starting in" }
        if plan.repsPerChime == 1 { return "current rep" }
        return "current set · \(engine.repsThisChime) reps"
    }

    private var clockFraction: Double {
        engine.phase == .ready ? 1 : engine.intervalFractionRemaining
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusHeader

            countdownBlock
                .padding(.top, 26)

            RepDotGrid(
                total: plan.targetReps,
                done: engine.completedReps,
                currentSet: engine.phase == .finished ? 0 : engine.repsThisChime
            )
            .padding(.top, 26)

            counterRow
                .padding(.top, 16)

            Spacer(minLength: 12)

            controls
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .paperBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            engine.onChime = { chimePlayer.play() }
            // the phone lies on the floor for the whole session — never sleep here
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onChange(of: engine.phase) { _, newPhase in
            if newPhase == .finished && !cancelled {
                showSummary = true
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            // whatever path led out of this screen, the engine must not
            // keep ticking (and chiming) behind it
            engine.stop()
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
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                StatusWord(word: statusWord)
                Spacer()
                Text("\(plan.targetReps) × \(plan.burpeeType.rawValue) · \(plan.repsPerChime) per set")
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.grey)
            }
            Rule()
        }
    }

    /// Countdown numerals plus the red clock bar. Fixed size at every target.
    private var countdownBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            if engine.phase == .ready {
                Text(Duration.seconds(plan.totalDuration), format: .time(pattern: .minuteSecond))
                    .font(Theme.display(104))
                    .foregroundStyle(Theme.ink)
            } else {
                // tenths ride the baseline small and grey: useful, not shouting
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(wholeSecondsRemaining)")
                        .font(Theme.display(104))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.linear(duration: 0.1), value: wholeSecondsRemaining)
                    Text(".\(tenthsRemaining)")
                        .font(Theme.display(40))
                        .foregroundStyle(Theme.grey)
                }
            }

            Text(countdownLabel)
                .label(color: Theme.grey)
                .padding(.top, 2)

            // red = time: the interval draining toward the next chime
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.track)
                    Rectangle()
                        .fill(Theme.red)
                        .frame(width: geo.size.width * clockFraction)
                        .animation(.linear(duration: 0.05), value: clockFraction)
                }
            }
            .frame(height: 8)
            .opacity(engine.phase == .paused ? 0.4 : 1)
            .padding(.top, 14)
        }
    }

    /// Done and to-go counts. Fixed size; only the grid above adapts.
    private var counterRow: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(engine.completedReps)")
                    .font(Theme.display(44))
                    .foregroundStyle(Theme.blue)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.3), value: engine.completedReps)
                Text("/\(plan.targetReps)")
                    .font(Theme.display(20))
                    .foregroundStyle(Theme.grey)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(plan.targetReps - engine.completedReps)")
                    .font(Theme.display(26))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.easeOut(duration: 0.3), value: engine.completedReps)
                Text("to go")
                    .label(color: Theme.grey)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 0) {
            switch engine.phase {
            case .ready:
                Button("cancel") { dismiss() }
                    .buttonStyle(OutlineBarButtonStyle())
                    .frame(width: 132)
                Button("start") { engine.start() }
                    .buttonStyle(InkBarButtonStyle(showDot: true))

            case .countingDown, .running, .paused:
                Button("stop") {
                    if engine.isCountingDown {
                        // Nothing performed yet — halt the engine and leave.
                        cancelled = true
                        engine.stop()
                        dismiss()
                    } else {
                        engine.stop()
                    }
                }
                .buttonStyle(OutlineBarButtonStyle(tint: Theme.red))
                .frame(width: 132)

                if engine.phase == .paused {
                    Button("resume") { engine.resume() }
                        .buttonStyle(InkBarButtonStyle())
                } else {
                    Button("pause") { engine.pause() }
                        .buttonStyle(InkBarButtonStyle())
                }

            case .finished:
                EmptyView()
            }
        }
    }
}

/// One dot per rep in a fixed box: blue = done, red = the set the next chime
/// asks for, ink outline = remaining. Dot size adapts so any target up to the
/// hundreds fits without overlap — pick the column count giving the largest
/// dot that fits the box both ways.
struct RepDotGrid: View {
    let total: Int
    let done: Int
    let currentSet: Int

    var body: some View {
        Canvas { ctx, size in
            guard total > 0 else { return }

            // find the best-fitting layout
            var best: (cols: Int, dot: CGFloat, gap: CGFloat) = (1, 0, 0)
            for cols in 6...30 {
                let rows = CGFloat((total + cols - 1) / cols)
                let gap = max(4, 24 / sqrt(rows))
                let dot = min(
                    (size.width - gap * CGFloat(cols - 1)) / CGFloat(cols),
                    (size.height - gap * rows + gap) / rows
                )
                if dot > best.dot { best = (cols, dot, gap) }
            }
            guard best.dot >= 3 else { return }

            // columns spread across the full width; rows top-aligned
            let dot = best.dot
            let xStep = best.cols > 1 ? (size.width - dot) / CGFloat(best.cols - 1) : 0
            let stroke = max(1.2, dot / 8)
            for i in 0..<total {
                let col = i % best.cols
                let row = i / best.cols
                let rect = CGRect(
                    x: CGFloat(col) * xStep,
                    y: CGFloat(row) * (dot + best.gap),
                    width: dot, height: dot
                )
                let path = Path(ellipseIn: rect.insetBy(dx: stroke / 2, dy: stroke / 2))
                if i < done {
                    ctx.fill(Path(ellipseIn: rect), with: .color(Theme.blue))
                } else if i < done + currentSet {
                    ctx.fill(Path(ellipseIn: rect), with: .color(Theme.red))
                } else {
                    ctx.stroke(path, with: .color(Theme.ink), lineWidth: stroke)
                }
            }
        }
        .frame(height: 266)
    }
}

#Preview {
    NavigationStack {
        TimerView(plan: WorkoutPlan(targetReps: 75, burpeeType: .sixCount, repsPerChime: 2, totalDuration: 120))
    }
    .environment(WorkoutStore(fileURL: URL.temporaryDirectory.appending(path: "preview-workouts.json")))
}
