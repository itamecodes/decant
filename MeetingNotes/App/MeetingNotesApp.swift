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
                // The design is a fixed light "blueprint" palette; lock to light
                // so system surfaces (List overscroll, sheets) never render dark.
                .preferredColorScheme(.light)
        }
        .modelContainer(for: [Note.self, ActionItem.self])
    }
}
