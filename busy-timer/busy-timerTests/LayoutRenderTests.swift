import SwiftUI
import XCTest

@testable import busy_timer

private final class LayoutHostingController<Content: View>: UIHostingController<Content> {
    override var prefersStatusBarHidden: Bool { true }
}

@MainActor
final class LayoutRenderTests: XCTestCase {
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
}
