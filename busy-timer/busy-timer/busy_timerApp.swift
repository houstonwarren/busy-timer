import SwiftUI

@main
struct busy_timerApp: App {
    @State private var workoutStore = WorkoutStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(workoutStore)
        }
    }
}
