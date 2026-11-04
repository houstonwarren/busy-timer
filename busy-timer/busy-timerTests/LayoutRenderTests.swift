import SwiftUI
import XCTest

@testable import busy_timer

// MARK: - Simulator renders

private final class LayoutHostingController<Content: View>: UIHostingController<Content> {
    override var prefersStatusBarHidden: Bool { true }
}

@MainActor
final class LayoutRenderTests: XCTestCase {
    private let portraitSizes: [(String, CGSize)] = [
        ("iphone", CGSize(width: 402, height: 874)),
        ("front", CGSize(width: 466, height: 678)),
        ("opened", CGSize(width: 669, height: 951)),
    ]

    /// Render the app's content at a fixed size, without simulated system chrome.
    private func capture(_ view: some View, size: CGSize, name: String, store: WorkoutStore) throws {
        let content =
            view
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

    /// Capture setup, ready, and working layouts at both Duo portrait sizes.
    func testDuoLayouts() throws {
        let file = URL.temporaryDirectory.appending(path: "layout-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let store = WorkoutStore(fileURL: file)
        store.add(Workout(burpeeType: .sixCount, targetReps: 100, completedReps: 100, secondsPerRep: 12))
        let plan = WorkoutPlan(targetReps: 100, burpeeType: .sixCount, repsPerChime: 2)

        for (name, size) in [
            ("front", CGSize(width: 466, height: 678)),
            ("opened", CGSize(width: 669, height: 951)),
        ] {
            try capture(SetupView(), size: size, name: "\(name)-setup", store: store)
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

    /// Render mixed-type history, empty history, and a single workout on iPhone and Duo.
    func testHistoryLayouts() throws {
        let file = URL.temporaryDirectory.appending(path: "history-layout-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let store = WorkoutStore(fileURL: file)

        for (name, size) in portraitSizes {
            try capture(HistoryView(), size: size, name: "\(name)-history-empty", store: store)
        }

        let firstDay = Date(timeIntervalSince1970: 1_793_361_600)
        store.add(Workout(date: firstDay, burpeeType: .sixCount, targetReps: 100, completedReps: 85, secondsPerRep: 12))
        for (name, size) in portraitSizes {
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
        for (name, size) in portraitSizes {
            try capture(HistoryView(), size: size, name: "\(name)-history", store: store)
        }
    }
}
