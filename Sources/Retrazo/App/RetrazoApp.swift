import SwiftUI
import AppKit

@main
struct RetrazoApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var settings = AppSettings.shared
    @StateObject private var binaryManager = BinaryManager.shared
    @StateObject private var queueManager = DownloadQueueManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 800, minHeight: 520)
                .background(VisualEffectBackground())
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            // File Menu
            CommandGroup(replacing: .newItem) {
                Button("New Download...") {
                    appState.presentNewDownload()
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Paste and Download") {
                    if let clip = NSPasteboard.general.string(forType: .string) {
                        appState.presentNewDownload(prefill: clip.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            }
            
            // View Navigation
            CommandGroup(after: .sidebar) {
                Button("Downloads") {
                    appState.selectedTab = .downloads
                }
                .keyboardShortcut("1", modifiers: .command)
                
                Button("History") {
                    appState.selectedTab = .history
                }
                .keyboardShortcut("2", modifiers: .command)
                
                Button("Settings") {
                    appState.selectedTab = .settings
                }
                .keyboardShortcut("3", modifiers: .command)
            }
            
            // Actions
            CommandMenu("Downloads") {
                Button("Clear Completed") {
                    queueManager.clearCompleted()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                
                Button("Cancel All Active") {
                    queueManager.cancelAll()
                }
                .keyboardShortcut(".", modifiers: .command)
                
                Divider()
                
                Button("Check for yt-dlp Updates") {
                    Task {
                        await binaryManager.checkForUpdates()
                        appState.selectedTab = .settings
                    }
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
            }
        }
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .underWindowBackground
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
