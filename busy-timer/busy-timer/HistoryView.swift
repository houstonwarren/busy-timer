import Charts
import SwiftUI

// MARK: - History

struct HistoryView: View {
    @Environment(WorkoutStore.self) private var workoutStore

    var body: some View {
        VStack(spacing: 8) {
            header
            history
        }
        .paperBackground()
        .toolbar(.visible, for: .navigationBar)
    }

    private var header: some View {
        Text("history")
            .font(Theme.display(21))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: Theme.contentWidth)
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .frame(maxWidth: .infinity)
    }

    private var history: some View {
        Group {
            if workoutStore.workouts.isEmpty {
                emptyState
            } else {
                List {
                    statRow
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 18, trailing: 24))

                    HistoryChart(days: workoutStore.dailyHistory)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 24, trailing: 24))

                    ForEach(workoutStore.workouts) { workout in
                        WorkoutRow(workout: workout)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 18, trailing: 24))
                    }
                    .onDelete { offsets in
                        workoutStore.delete(atOffsets: offsets)
                    }
                }
                .frame(maxWidth: Theme.contentWidth + 48)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// Keep lifetime 6-count and 10-count reps separate above the daily chart.
    private var statRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("^[\(workoutStore.workouts.count) workout](inflect: true) · all time").label(color: Theme.grey)
            HStack(spacing: 24) {
                ForEach(BurpeeType.allCases) { type in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(workoutStore.totalCompletedReps(of: type))")
                            .font(Theme.display(36))
                            .foregroundStyle(type == .sixCount ? Theme.blue : Theme.ink)
                        Text("\(type.rawValue) burpees").label(color: Theme.grey)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Rule()
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            StatusWord(word: "nothing yet")
            Text("your first twenty minutes will land here.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.grey)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

// MARK: - Daily chart

struct HistoryChart: View {
    let days: [WorkoutDay]
    @State private var selectedDate: Date?

    private var selectedDay: WorkoutDay? {
        guard let selectedDate else { return nil }
        let date = Calendar.current.startOfDay(for: selectedDate)
        return days.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("daily reps").label()
                Spacer()
                if let selectedDay {
                    Text(selectedDay.date, format: .dateTime.month(.abbreviated).day().year())
                } else {
                    Text("touch & hold to explore")
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.grey)

            Chart {
                ForEach(days) { day in
                    ForEach(BurpeeType.allCases) { type in
                        if day.repsByType[type] != nil {
                            LineMark(
                                x: .value("Day", day.date),
                                y: .value("Completed reps", day.completedReps(of: type))
                            )
                            .foregroundStyle(by: .value("Burpee type", type.rawValue))
                            .symbol(by: .value("Burpee type", type.rawValue))
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .accessibilityLabel(
                                "\(day.date.formatted(date: .abbreviated, time: .omitted)), \(type.rawValue)"
                            )
                            .accessibilityValue("\(day.completedReps(of: type)) completed reps")
                        }
                    }
                }
                if let selectedDay {
                    RuleMark(x: .value("Selected day", selectedDay.date))
                        .foregroundStyle(Theme.ink.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            .chartForegroundStyleScale(["6-count": Theme.blue, "10-count": Theme.ink])
            .chartSymbolScale(["6-count": BasicChartSymbolShape.circle, "10-count": .square])
            .chartLegend(position: .bottom, alignment: .leading, spacing: 12)
            .chartXScale(range: .plotDimension(padding: 8))
            .chartXAxis {
                if days.count == 1 {
                    AxisMarks(values: days.map(\.date)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                } else {
                    AxisMarks(values: .automatic(desiredCount: 4)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                    AxisGridLine().foregroundStyle(Theme.track)
                    AxisValueLabel()
                }
            }
            .chartXSelection(value: $selectedDate)
            .sensoryFeedback(.selection, trigger: selectedDay?.date)
            .frame(height: 170)

            HStack(spacing: 18) {
                if let selectedDay {
                    ForEach(BurpeeType.allCases) { type in
                        Text("\(type.rawValue): \(selectedDay.completedReps(of: type)) reps")
                            .foregroundStyle(type == .sixCount ? Theme.blue : Theme.ink)
                    }
                } else {
                    Text("completed burpees by workout day")
                        .foregroundStyle(Theme.grey)
                }
            }
            .font(.system(size: 12, weight: .medium))
            .monospacedDigit()
            .accessibilityIdentifier("history-chart-readout")
            Rule()
        }
    }
}

// MARK: - Workout list

private struct WorkoutRow: View {
    let workout: Workout

    private var hitTarget: Bool { workout.completedReps >= workout.targetReps }

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(workout.date, format: .dateTime.month().day().year())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(
                        "\(workout.burpeeType.rawValue) · \(workout.secondsPerRep, format: .number.precision(.fractionLength(1)))s/rep"
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.grey)
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(workout.completedReps)")
                        .font(Theme.display(24))
                        .foregroundStyle(hitTarget ? Theme.blue : Theme.ink)
                    Text("/\(workout.targetReps)")
                        .font(Theme.display(14))
                        .foregroundStyle(Theme.grey)
                }
            }

            // blue = reps done, as everywhere
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.track)
                    Rectangle()
                        .fill(Theme.blue)
                        .frame(width: geo.size.width * min(1, workout.completionFraction))
                }
            }
            .frame(height: 4)
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .environment(WorkoutStore(fileURL: URL.temporaryDirectory.appending(path: "preview-workouts.json")))
}
