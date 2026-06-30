import SwiftUI
import SwiftData

@main
struct iosproApp: App {
    @State private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .preferredColorScheme(.dark)
        }
        .modelContainer(WorkoutStore.shared.container)
    }
}