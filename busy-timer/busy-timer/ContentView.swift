import SwiftUI

struct ContentView: View {
    @Environment(WorkoutStore.self) private var workoutStore

    @State private var targetReps: Int?
    @State private var burpeeType: BurpeeType = .sixCount
    @State private var repsPerChime = 1
    @State private var activePlan: WorkoutPlan?
    @FocusState private var repsFocused: Bool

    private let batchChoices = [1, 2, 3, 5]

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
                VStack(alignment: .leading, spacing: 14) {
                    header
                    targetCard
                    typeCard
                    batchCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .paperBackground()
            .safeAreaInset(edge: .bottom) {
                Button {
                    repsFocused = false
                    activePlan = draftPlan
                } label: {
                    Text("Start workout")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(draftPlan == nil)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .background(Theme.paper.opacity(0.92))
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
            .toolbarBackground(Theme.paper, for: .navigationBar)
            .navigationDestination(item: $activePlan) { plan in
                TimerView(plan: plan)
            }
        }
        .tint(Theme.pine)
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
        ZStack(alignment: .bottomLeading) {
            BreathField()
                .frame(height: 210)
                .padding(.horizontal, -20)
            VStack(alignment: .leading, spacing: 8) {
                Text("Busy Timer")
                    .overline(color: Theme.pine)
                Text("Twenty minutes.\nJust burpees.")
                    .font(Theme.display(40))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(2)
            }
            .padding(.bottom, 6)
        }
    }

    private var targetCard: some View {
        VStack(spacing: 12) {
            Text("Target Reps")
                .overline()
            HStack(spacing: 20) {
                AdjustButton(systemImage: "minus") {
                    let next = (targetReps ?? 0) - 1
                    targetReps = next > 0 ? next : nil
                }
                TextField("0", value: $targetReps, format: .number)
                    .keyboardType(.numberPad)
                    .focused($repsFocused)
                    .font(Theme.display(60))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .tint(Theme.pine)
                AdjustButton(systemImage: "plus") {
                    targetReps = min(999, (targetReps ?? 0) + 1)
                }
            }
            if let last = lastWorkout {
                Text("Last \(burpeeType.rawValue): \(last.completedReps) reps")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .card()
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

    private var batchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reps Per Chime")
                .overline()
            HStack(spacing: 6) {
                ForEach(batchChoices, id: \.self) { batch in
                    ChoiceChip(title: "\(batch)", isSelected: repsPerChime == batch) {
                        repsPerChime = batch
                    }
                }
            }
            if let plan = draftPlan {
                Text("Chime every \(plan.secondsPerChime, format: .number.precision(.fractionLength(0)))s — do \(plan.repsPerChime) each time.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.2), value: plan)
            } else {
                Text("Set a target to see your pace.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textFaint)
            }
        }
        .card(padding: 16)
    }
}

/// Round bordered − / + button flanking the target field.
struct AdjustButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.pine)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Theme.paper)
                        .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }
}

/// The home screen's one flourish: soft discs that swell and settle on a slow
/// breath cadence behind the headline. Pure ambience — the brand is air and
/// unhurried time, so nothing here blinks or demands a tap.
struct BreathField: View {
    // x/y are fractions of the field; lag staggers each disc's breath.
    private struct Disc {
        var x: Double
        var y: Double
        var radius: Double
        var lag: Double
        var tint: Color
    }

    private static let discs: [Disc] = [
        Disc(x: 0.80, y: 0.34, radius: 130, lag: 0.00, tint: Theme.air),
        Disc(x: 0.58, y: 0.68, radius: 85, lag: 0.28, tint: Theme.sage),
        Disc(x: 0.95, y: 0.78, radius: 65, lag: 0.55, tint: Theme.air),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            Canvas { ctx, size in
                let t: Double = context.date.timeIntervalSinceReferenceDate
                // one full breath every 9 seconds
                for disc in Self.discs {
                    let breath: Double = (sin((t / 9 - disc.lag) * 2 * .pi - .pi / 2) + 1) / 2
                    let radius: Double = disc.radius * (0.80 + 0.20 * breath)
                    let driftX: Double = sin(t / 13 + disc.lag * 7) * 7
                    let driftY: Double = cos(t / 11 + disc.lag * 5) * 5
                    let center = CGPoint(
                        x: Double(size.width) * disc.x + driftX,
                        y: Double(size.height) * disc.y + driftY
                    )
                    let rect = CGRect(
                        x: center.x - radius, y: center.y - radius,
                        width: radius * 2, height: radius * 2
                    )
                    ctx.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            Gradient(colors: [disc.tint.opacity(0.55), disc.tint.opacity(0)]),
                            center: center,
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    ContentView()
        .environment(WorkoutStore(fileURL: URL.temporaryDirectory.appending(path: "preview-workouts.json")))
}
