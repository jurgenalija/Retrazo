import SwiftUI
import Combine

enum NavigationTab: String, CaseIterable, Identifiable {
    case downloads = "Downloads"
    case history = "History"
    case settings = "Settings"
    case about = "About"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .downloads: return "arrow.down.circle"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        case .about: return "info.circle"
        }
    }
}

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var selectedTab: NavigationTab = .downloads
    
    // Sheets & Dialogs
    @Published var isShowingNewDownloadSheet: Bool = false
    @Published var newDownloadPrefillURL: String = ""
    
    @Published var selectedLogItem: DownloadItem? = nil
    @Published var isShowingLogSheet: Bool = false
    
    @Published var isShowingUpdateModal: Bool = false
    
    // Quick URL field in DownloadsView
    @Published var quickURLText: String = ""
    
    // Alert info
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    @Published var isShowingAlert: Bool = false
    
    let settings = AppSettings.shared
    let binaryManager = BinaryManager.shared
    let queueManager = DownloadQueueManager.shared
    let clipboardWatcher = ClipboardWatcher.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        clipboardWatcher.$lastDetectedURL
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                guard let self = self else { return }
                if self.quickURLText.isEmpty {
                    self.quickURLText = url
                }
            }
            .store(in: &cancellables)
    }
    
    func presentNewDownload(prefill: String? = nil) {
        if let prefill = prefill, !prefill.isEmpty {
            self.newDownloadPrefillURL = prefill
        } else if !quickURLText.isEmpty {
            self.newDownloadPrefillURL = quickURLText
        } else {
            self.newDownloadPrefillURL = ""
        }
        self.isShowingNewDownloadSheet = true
    }
    
    func presentLogs(for item: DownloadItem) {
        self.selectedLogItem = item
        self.isShowingLogSheet = true
    }
    
    func showAlert(title: String, message: String) {
        self.alertTitle = title
        self.alertMessage = message
        self.isShowingAlert = true
    }
}
