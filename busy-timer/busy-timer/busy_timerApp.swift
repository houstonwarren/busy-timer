import SwiftUI

@main
struct busy_timerApp: App {
    @State private var workoutStore = WorkoutStore(backup: KeychainBackup())

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(workoutStore)
                // The design language is built on a paper palette; the app
                // commits to light rendering regardless of system appearance.
                .preferredColorScheme(.light)
                .tint(Theme.ink)
        }
    }
}
