import SwiftUI
import AppKit

@main
struct RetrazoApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var settings = AppSettings.shared
    @StateObject private var binaryManager = BinaryManager.shared
    @StateObject private var appUpdateManager = AppUpdateManager.shared
    @StateObject private var queueManager = DownloadQueueManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 800, minHeight: 520)
                .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
                .tint(settings.appAccentColor.color)
                .accentColor(settings.appAccentColor.color)
                .preferredColorScheme(settings.appTheme.colorScheme)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Retrazo Updates…") {
                    appState.selectedTab = .settingsEngine
                    Task {
                        await appUpdateManager.checkForUpdates()
                    }
                }
                .disabled(appUpdateManager.isBusy)
            }

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
            
            // View Navigation & Appearance
            CommandGroup(replacing: .sidebar) {
                Button("Downloads") {
                    appState.selectedTab = .downloads
                }
                .keyboardShortcut("1", modifiers: .command)
                
                Button("History") {
                    appState.selectedTab = .history
                }
                .keyboardShortcut("2", modifiers: .command)
                
                Button("Settings") {
                    appState.selectedTab = .settingsGeneral
                }
                .keyboardShortcut("3", modifiers: .command)
                
                Divider()
                
                Menu("Appearance") {
                    ForEach(AppTheme.allCases) { theme in
                        Button(action: {
                            settings.appTheme = theme
                        }) {
                            HStack {
                                Text(theme.rawValue)
                                if settings.appTheme == theme {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
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
                        appState.selectedTab = .settingsEngine
                    }
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
            }
        }
    }
}
