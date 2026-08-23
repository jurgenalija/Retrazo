import SwiftUI

struct MainView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var queueManager = DownloadQueueManager.shared
    @ObservedObject var binaryManager = BinaryManager.shared
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $appState.selectedTab) {
                Section("Media Downloader") {
                    NavigationLink(value: NavigationTab.downloads) {
                        HStack {
                            Label(NavigationTab.downloads.rawValue, systemImage: NavigationTab.downloads.icon)
                            Spacer()
                            if activeCount > 0 {
                                Text("\(activeCount)")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    
                    NavigationLink(value: NavigationTab.history) {
                        HStack {
                            Label(NavigationTab.history.rawValue, systemImage: NavigationTab.history.icon)
                            Spacer()
                            if !queueManager.historyDownloads.isEmpty {
                                Text("\(queueManager.historyDownloads.count)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section("Preferences") {
                    NavigationLink(value: NavigationTab.settings) {
                        HStack {
                            Label(NavigationTab.settings.rawValue, systemImage: NavigationTab.settings.icon)
                            Spacer()
                            if binaryManager.isUpdateAvailable {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                    
                    NavigationLink(value: NavigationTab.about) {
                        Label(NavigationTab.about.rawValue, systemImage: NavigationTab.about.icon)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            // Detail Area
            Group {
                switch appState.selectedTab {
                case .downloads:
                    DownloadsView()
                case .history:
                    HistoryView()
                case .settings:
                    SettingsView()
                case .about:
                    AboutView()
                }
            }
            .navigationTitle(appState.selectedTab.rawValue)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if appState.selectedTab == .downloads {
                        Button(action: {
                            appState.presentNewDownload()
                        }) {
                            Label("New Download", systemImage: "plus")
                        }
                        .help("Add New Download (⌘N)")
                    }
                }
            }
        }
        .sheet(isPresented: $appState.isShowingNewDownloadSheet) {
            NewDownloadSheet(prefillURL: appState.newDownloadPrefillURL)
        }
        .sheet(isPresented: $appState.isShowingLogSheet) {
            if let item = appState.selectedLogItem {
                LogSheetView(item: item)
            }
        }
        .alert(isPresented: $appState.isShowingAlert) {
            Alert(
                title: Text(appState.alertTitle),
                message: Text(appState.alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private var activeCount: Int {
        queueManager.activeDownloads.filter { $0.status.isActive }.count
    }
}
