import SwiftUI
import SwiftData

@main
struct MeetingNotesApp: App {
    /// App-wide settings (API key + model choices). One instance for the app lifetime.
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
        }
        .modelContainer(for: [Note.self, ActionItem.self])
    }
}
