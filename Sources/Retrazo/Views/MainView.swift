import SwiftUI
import AppKit

struct MainView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var appState = AppState.shared
    @ObservedObject var binaryManager = BinaryManager.shared
    @ObservedObject var appUpdateManager = AppUpdateManager.shared
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $appState.selectedTab) {
                Section("Media Downloader") {
                    NavigationLink(value: NavigationTab.downloads) {
                        HStack {
                            SidebarLabel(
                                tab: .downloads,
                                isSelected: appState.selectedTab == .downloads
                            )
                            Spacer()
                            ActiveDownloadCountBadge()
                        }
                    }
                    
                    NavigationLink(value: NavigationTab.history) {
                        HStack {
                            SidebarLabel(
                                tab: .history,
                                isSelected: appState.selectedTab == .history
                            )
                            Spacer()
                            DownloadHistoryCountBadge()
                        }
                    }
                }
                
                Section("Settings") {
                    NavigationLink(value: NavigationTab.settingsGeneral) {
                        SidebarLabel(
                            tab: .settingsGeneral,
                            isSelected: appState.selectedTab == .settingsGeneral
                        )
                    }

                    NavigationLink(value: NavigationTab.settingsFormats) {
                        SidebarLabel(
                            tab: .settingsFormats,
                            isSelected: appState.selectedTab == .settingsFormats
                        )
                    }

                    NavigationLink(value: NavigationTab.settingsAdvanced) {
                        SidebarLabel(
                            tab: .settingsAdvanced,
                            isSelected: appState.selectedTab == .settingsAdvanced
                        )
                    }

                    NavigationLink(value: NavigationTab.settingsEngine) {
                        HStack {
                            SidebarLabel(
                                tab: .settingsEngine,
                                isSelected: appState.selectedTab == .settingsEngine
                            )
                            Spacer()
                            if binaryManager.isUpdateAvailable || appUpdateManager.isUpdateAvailable {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                }

                Section("Retrazo") {
                    NavigationLink(value: NavigationTab.about) {
                        SidebarLabel(
                            tab: .about,
                            isSelected: appState.selectedTab == .about
                        )
                    }
                }
            }
            .listStyle(.sidebar)
            .modifier(SidebarToggleRemovalModifier())
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            // Detail Area
            Group {
                switch appState.selectedTab {
                case .downloads:
                    DownloadsView()
                case .history:
                    HistoryView()
                case .settingsGeneral:
                    SettingsView(selectedTab: .general)
                case .settingsEngine:
                    SettingsView(selectedTab: .engine)
                case .settingsFormats:
                    SettingsView(selectedTab: .formats)
                case .settingsAdvanced:
                    SettingsView(selectedTab: .advanced)
                case .about:
                    AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(finderContentBackground.ignoresSafeArea())
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
        .modifier(SidebarToggleRemovalModifier())
        .background(WindowSidebarRemover())
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
    
    private var finderContentBackground: Color {
        if colorScheme == .dark {
            // NSColor.windowBackgroundColor resolves to Finder's #1E1E1E content surface.
            return Color(red: 30 / 255, green: 30 / 255, blue: 30 / 255)
        }
        return Color(nsColor: .windowBackgroundColor)
    }
}

private struct SidebarToggleRemovalModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.toolbar(removing: .sidebarToggle)
        } else {
            content
        }
    }
}

private struct WindowSidebarRemover: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowSidebarRemovalView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? WindowSidebarRemovalView)?.removeToggle()
    }
}

private final class WindowSidebarRemovalView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(toolbarDidUpdate(_:)),
            name: NSToolbar.willAddItemNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeToggle()
        if let window = window {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidBecomeKey(_:)),
                name: NSWindow.didBecomeKeyNotification,
                object: window
            )
        }
    }

    @objc private func toolbarDidUpdate(_ notification: Notification) {
        removeToggle()
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        removeToggle()
    }

    fileprivate func removeToggle() {
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.window else { return }

            if let toolbar = window.toolbar {
                for i in toolbar.items.indices.reversed() {
                    let item = toolbar.items[i]
                    let id = item.itemIdentifier.rawValue
                    let actionStr = item.action != nil ? NSStringFromSelector(item.action!) : ""
                    if id.localizedCaseInsensitiveContains("sidebar") ||
                       actionStr.localizedCaseInsensitiveContains("sidebar") ||
                       id == "NSToolbarToggleSidebarItem" {
                        toolbar.removeItem(at: i)
                    }
                }
            }

            func disableSidebarCollapse(in vc: NSViewController?) {
                guard let vc = vc else { return }
                if let split = vc as? NSSplitViewController {
                    for item in split.splitViewItems {
                        if item.behavior == .sidebar {
                            item.canCollapse = false
                        }
                    }
                }
                for child in vc.children {
                    disableSidebarCollapse(in: child)
                }
            }
            disableSidebarCollapse(in: window.contentViewController)
        }
    }
}

private struct ActiveDownloadCountBadge: View {
    @ObservedObject private var queueManager = DownloadQueueManager.shared

    var body: some View {
        let count = queueManager.activeDownloads.lazy.filter { $0.status.isActive }.count
        if count > 0 {
            Text("\(count)")
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(Capsule())
        }
    }
}

private struct DownloadHistoryCountBadge: View {
    @ObservedObject private var queueManager = DownloadQueueManager.shared

    var body: some View {
        if !queueManager.historyDownloads.isEmpty {
            Text("\(queueManager.historyDownloads.count)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

private struct SidebarLabel: View {
    @ObservedObject private var settings = AppSettings.shared
    let tab: NavigationTab
    let isSelected: Bool

    var body: some View {
        Label {
            Text(tab.rawValue)
        } icon: {
            Image(systemName: tab.icon)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(isSelected ? Color.primary : settings.appAccentColor.color)
        }
    }
}
