import SwiftUI

@main
struct PediatricsRAGMacApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 1320, idealWidth: 1420, minHeight: 820, idealHeight: 900)
        }
        .defaultSize(width: 1420, height: 900)
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView()
                .environmentObject(viewModel)
                .frame(width: 520, height: 340)
        }
    }
}
