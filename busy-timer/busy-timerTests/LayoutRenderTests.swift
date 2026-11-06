import SwiftUI
import XCTest

@testable import busy_timer

// MARK: - Simulator renders

private final class LayoutHostingController<Content: View>: UIHostingController<Content> {
    override var prefersStatusBarHidden: Bool { true }
}

@MainActor
final class LayoutRenderTests: XCTestCase {
    private let layoutSizes: [(String, CGSize)] = [
        ("iphone", CGSize(width: 402, height: 874)),
        ("front", CGSize(width: 466, height: 678)),
        ("opened", CGSize(width: 669, height: 951)),
        ("opened-landscape", CGSize(width: 951, height: 669)),
        ("front-short", CGSize(width: 466, height: 320)),
        ("opened-split", CGSize(width: 320, height: 600)),
    ]

    /// Render the app's content at a fixed size, without simulated system chrome.
    private func capture(_ view: some View, size: CGSize, name: String, store: WorkoutStore) throws {
        let content =
            NavigationStack {
                view
                    .toolbar(.hidden, for: .navigationBar)
            }
            .environment(store)
            .preferredColorScheme(.light)
            .frame(width: size.width, height: size.height)
            .background(Theme.paper)
        let host = LayoutHostingController(rootView: content)
        host.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            XCTAssertTrue(host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true))
        }
        let attachment = XCTAttachment(data: try XCTUnwrap(image.pngData()), uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        window.isHidden = true
    }

    /// Capture setup, timer, and summary at full, split, and reduced window sizes.
    func testDuoLayouts() throws {
        let file = URL.temporaryDirectory.appending(path: "layout-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let store = WorkoutStore(fileURL: file)
        store.add(Workout(burpeeType: .sixCount, targetReps: 100, completedReps: 100, secondsPerRep: 12))
        let plan = WorkoutPlan(targetReps: 100, burpeeType: .sixCount, repsPerChime: 2)

        for (name, size) in layoutSizes {
            try capture(SetupView(), size: size, name: "\(name)-setup", store: store)
            try capture(
                WorkoutSummaryView(plan: plan, promptedReps: 36) { _ in },
                size: size, name: "\(name)-summary", store: store)
            try capture(
                TimerView(plan: plan), size: size, name: "\(name)-ready", store: store)

            let engine = WorkoutEngine(plan: plan, autoTicks: false)
            let start = Date(timeIntervalSinceReferenceDate: 0)
            engine.start(now: start)
            engine.tick(now: start.addingTimeInterval(446.2))
            try capture(
                TimerView(plan: plan, engine: engine),
                size: size, name: "\(name)-running", store: store)
        }
    }

    /// Render the real arrangement's two sections without requiring a hardware fold.
    func testTabletopTimerLayouts() throws {
        guard #available(iOS 27.1, *) else { return }
        let file = URL.temporaryDirectory.appending(path: "tabletop-layout-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let store = WorkoutStore(fileURL: file)
        let plan = WorkoutPlan(targetReps: 100, burpeeType: .sixCount, repsPerChime: 2)
        let start = Date(timeIntervalSinceReferenceDate: 0)

        for (name, size) in [
            ("opened-tabletop", CGSize(width: 669, height: 951)),
            ("opened-tabletop-small", CGSize(width: 500, height: 720)),
        ] {
            let engine = WorkoutEngine(plan: plan, autoTicks: false)
            for phase in ["ready", "running", "paused"] {
                if phase == "running" {
                    engine.start(now: start)
                    engine.tick(now: start.addingTimeInterval(446.2))
                } else if phase == "paused" {
                    engine.pause(now: start.addingTimeInterval(446.2))
                }
                try capture(
                    TimerView(plan: plan, engine: engine).tabletopLayout
                        .environment(\.horizontalSizeClass, .regular)
                        .environment(\.verticalSizeClass, .regular),
                    size: size, name: "\(name)-\(phase)", store: store)
            }
        }
    }

    /// Resize one mounted timer; a running or paused workout must retain its interval and reps.
    func testTimerKeepsWorkoutWhenResized() throws {
        let file = URL.temporaryDirectory.appending(path: "resize-layout-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let store = WorkoutStore(fileURL: file)
        let plan = WorkoutPlan(targetReps: 100, burpeeType: .sixCount, repsPerChime: 2)
        let engine = WorkoutEngine(plan: plan, autoTicks: false)
        let start = Date(timeIntervalSinceReferenceDate: 0)
        engine.start(now: start)
        engine.tick(now: start.addingTimeInterval(446.2))
        let reps = engine.completedReps
        let remaining = engine.timeRemaining
        let host = LayoutHostingController(
            rootView:
                NavigationStack {
                    TimerView(plan: plan, engine: engine)
                }.environment(store))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 466, height: 678))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            engine.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }

        for phase in [WorkoutEngine.Phase.running, .paused] {
            if phase == .paused { engine.pause(now: start.addingTimeInterval(446.2)) }
            for size in [
                CGSize(width: 669, height: 951), CGSize(width: 951, height: 669), CGSize(width: 466, height: 678),
            ] {
                window.frame = CGRect(origin: .zero, size: size)
                host.view.frame = window.bounds
                host.view.layoutIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.1))
                XCTAssertEqual(engine.phase, phase)
                XCTAssertEqual(engine.completedReps, reps)
                XCTAssertEqual(engine.timeRemaining, remaining, accuracy: 0.001)
            }
        }
    }

    /// Render both side-bar placements; controls must stay within the remaining width.
    func testAsymmetricInsets() throws {
        let file = URL.temporaryDirectory.appending(path: "inset-layout-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let store = WorkoutStore(fileURL: file)
        let plan = WorkoutPlan(targetReps: 100, burpeeType: .sixCount, repsPerChime: 2)
        let size = CGSize(width: 466, height: 678)
        for (name, insets) in [
            ("leading", EdgeInsets(top: 20, leading: 80, bottom: 20, trailing: 0)),
            ("trailing", EdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 80)),
        ] {
            try capture(
                SetupView().safeAreaPadding(insets), size: size,
                name: "front-\(name)-setup", store: store)
            try capture(
                TimerView(plan: plan).safeAreaPadding(insets), size: size,
                name: "front-\(name)-ready", store: store)
        }
    }

    /// Render history with no workouts, one workout, and mixed burpee types.
    func testHistoryLayouts() throws {
        let file = URL.temporaryDirectory.appending(path: "history-layout-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let store = WorkoutStore(fileURL: file)

        for (name, size) in layoutSizes {
            try capture(HistoryView(), size: size, name: "\(name)-history-empty", store: store)
        }

        let firstDay = Date(timeIntervalSince1970: 1_793_361_600)
        store.add(Workout(date: firstDay, burpeeType: .sixCount, targetReps: 100, completedReps: 85, secondsPerRep: 12))
        for (name, size) in layoutSizes {
            try capture(HistoryView(), size: size, name: "\(name)-history-single", store: store)
        }

        for (offset, six, ten) in [(2, 92, 50), (4, 100, 56), (7, 105, 60), (9, 110, 68), (11, 120, 75)] {
            let date = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: offset, to: firstDay))
            for (type, reps) in [(BurpeeType.sixCount, six), (.tenCount, ten)] {
                store.add(
                    Workout(
                        date: date, burpeeType: type, targetReps: reps, completedReps: reps,
                        secondsPerRep: 1200 / Double(reps)))
            }
        }
        for (name, size) in layoutSizes {
            try capture(HistoryView(), size: size, name: "\(name)-history", store: store)
        }
    }
}
