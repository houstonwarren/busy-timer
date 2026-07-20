import SwiftUI

struct ContentView: View {
    @Environment(WorkoutStore.self) private var workoutStore

    @State private var targetReps: Int?
    @State private var burpeeType: BurpeeType = .sixCount
    @State private var durationMinutes = 20
    @State private var activePlan: WorkoutPlan?

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
            Form {
                Section("Workout") {
                    TextField("How many burpees?", value: $targetReps, format: .number)
                        .keyboardType(.numberPad)

                    Picker("Type", selection: $burpeeType) {
                        ForEach(BurpeeType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Duration", selection: $durationMinutes) {
                        ForEach(durationChoices, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                }

                if let plan = draftPlan {
                    Section {
                        LabeledContent("Pace") {
                            Text("\(plan.secondsPerRep, format: .number.precision(.fractionLength(1)))s per rep")
                        }
                    }
                }

                Section {
                    Button {
                        activePlan = draftPlan
                    } label: {
                        Label("Werkout", systemImage: "figure.strengthtraining.functional")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(draftPlan == nil)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Busy Timer")
            .toolbar {
                NavigationLink {
                    HistoryView()
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            }
            .navigationDestination(item: $activePlan) { plan in
                TimerView(plan: plan)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(WorkoutStore(fileURL: URL.temporaryDirectory.appending(path: "preview-workouts.json")))
}
