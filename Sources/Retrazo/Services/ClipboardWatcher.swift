import AppKit
import Combine

final class ClipboardWatcher: ObservableObject {
    static let shared = ClipboardWatcher()
    
    @Published var lastDetectedURL: String? = nil
    
    private var timer: Timer?
    private var lastChangeCount = 0
    private var lastProcessedURL: String = ""
    private var settingsCancellable: AnyCancellable?
    
    init() {
        settingsCancellable = AppSettings.shared.$clipboardMonitoring
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] isEnabled in
                if isEnabled {
                    self?.start()
                } else {
                    self?.stop()
                }
            }
    }
    
    func start() {
        guard timer == nil else { return }
        lastChangeCount = NSPasteboard.general.changeCount
        
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
        timer.tolerance = 0.75
        RunLoop.main.add(timer, forMode: .default)
        self.timer = timer
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        
        guard let string = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty,
              string != lastProcessedURL else { return }
        
        if isValidMediaURL(string) {
            lastProcessedURL = string
            lastDetectedURL = string
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
