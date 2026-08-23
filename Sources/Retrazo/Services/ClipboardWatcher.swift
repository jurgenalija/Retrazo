import AppKit
import Combine

class ClipboardWatcher: ObservableObject {
    static let shared = ClipboardWatcher()
    
    @Published var lastDetectedURL: String? = nil
    
    private var timer: Timer?
    private var lastChangeCount = 0
    private var lastProcessedURL: String = ""
    
    init() {
        start()
    }
    
    func start() {
        timer?.invalidate()
        lastChangeCount = NSPasteboard.general.changeCount
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkPasteboard() {
        guard AppSettings.shared.clipboardMonitoring else { return }
        
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        
        guard let string = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty,
              string != lastProcessedURL else { return }
        
        if isValidMediaURL(string) {
            lastProcessedURL = string
            DispatchQueue.main.async {
                self.lastDetectedURL = string
            }
        }
    }
    
    private func isValidMediaURL(_ text: String) -> Bool {
        guard let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              let host = url.host?.lowercased() else { return false }
        
        return Constants.SupportedPlatforms.isSupported(url: text) ||
               host.contains("youtube") ||
               host.contains("youtu.be") ||
               host.contains("vimeo") ||
               host.contains("twitter") ||
               host.contains("x.com") ||
               host.contains("tiktok") ||
               host.contains("twitch") ||
               host.contains("instagram") ||
               host.contains("facebook") ||
               host.contains("reddit") ||
               host.contains("bilibili") ||
               host.contains("soundcloud") ||
               host.contains("bandcamp")
    }
}
