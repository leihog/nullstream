import SwiftUI

@main
struct NullStreamApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .background(Color("NullBackground"))
                .foregroundStyle(Color("PrimaryTextColor"))
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Playback") {
                Button("Play/Pause") {
                    appState.togglePlayPause()
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(!appState.canControlPlayback)
            }
        }
    }
}
