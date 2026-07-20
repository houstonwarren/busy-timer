import SwiftUI

@main
struct busy_timerApp: App {
    @State private var workoutStore = WorkoutStore(backup: KeychainBackup())

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(workoutStore)
                // The design language is built on an ink-dark palette; the app
                // commits to dark rendering regardless of system appearance.
                .preferredColorScheme(.dark)
                .tint(Theme.volt)
        }
    }
}
