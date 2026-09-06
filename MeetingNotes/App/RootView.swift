import SwiftUI

/// Hosts the navigation stack and nudges first-run users to Settings until a key is set.
struct RootView: View {
    @Environment(AppSettings.self) private var settings
    @State private var showingSettingsOnLaunch = false

    var body: some View {
        NotesListView()
        .sheet(isPresented: $showingSettingsOnLaunch) {
            NavigationStack {
                SettingsView()
            }
        }
        .task {
            // On first launch with no key, open Settings so the app is usable.
            if !settings.isConfigured {
                showingSettingsOnLaunch = true
            }
        }
    }
}
