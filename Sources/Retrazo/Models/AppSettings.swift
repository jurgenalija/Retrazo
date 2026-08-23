import SwiftUI
import Combine
import AppKit

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .system: return "circle.righthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    // Appearance
    @Published var appTheme: AppTheme {
        didSet {
            defaults.set(appTheme.rawValue, forKey: "appTheme")
            applyTheme()
        }
    }
    
    // Download Locations
    @Published var downloadDirectory: String {
        didSet { defaults.set(downloadDirectory, forKey: "downloadDirectory") }
    }
    
    // Default Preset
    @Published var defaultPresetId: String {
        didSet { defaults.set(defaultPresetId, forKey: "defaultPresetId") }
    }
    
    // Queue limits
    @Published var maxConcurrentDownloads: Int {
        didSet { defaults.set(maxConcurrentDownloads, forKey: "maxConcurrentDownloads") }
    }
    
    // Engine / Updates
    @Published var autoCheckYtDlpUpdates: Bool {
        didSet { defaults.set(autoCheckYtDlpUpdates, forKey: "autoCheckYtDlpUpdates") }
    }
    
    @Published var customYtDlpPath: String {
        didSet { defaults.set(customYtDlpPath, forKey: "customYtDlpPath") }
    }
    
    @Published var customFfmpegPath: String {
        didSet { defaults.set(customFfmpegPath, forKey: "customFfmpegPath") }
    }
    
    // Embedding Options
    @Published var embedThumbnail: Bool {
        didSet { defaults.set(embedThumbnail, forKey: "embedThumbnail") }
    }
    
    @Published var embedMetadata: Bool {
        didSet { defaults.set(embedMetadata, forKey: "embedMetadata") }
    }
    
    @Published var embedChapters: Bool {
        didSet { defaults.set(embedChapters, forKey: "embedChapters") }
    }
    
    @Published var embedSubtitles: Bool {
        didSet { defaults.set(embedSubtitles, forKey: "embedSubtitles") }
    }
    
    @Published var subtitleLanguage: String {
        didSet { defaults.set(subtitleLanguage, forKey: "subtitleLanguage") }
    }
    
    // SponsorBlock
    @Published var sponsorBlockEnabled: Bool {
        didSet { defaults.set(sponsorBlockEnabled, forKey: "sponsorBlockEnabled") }
    }
    
    @Published var sponsorBlockCategories: String {
        didSet { defaults.set(sponsorBlockCategories, forKey: "sponsorBlockCategories") }
    }
    
    // Cookies / Auth
    @Published var browserCookies: String {
        didSet { defaults.set(browserCookies, forKey: "browserCookies") }
    }
    
    @Published var customCookiesPath: String {
        didSet { defaults.set(customCookiesPath, forKey: "customCookiesPath") }
    }
    
    // Filename & Advanced
    @Published var filenameTemplate: String {
        didSet { defaults.set(filenameTemplate, forKey: "filenameTemplate") }
    }
    
    @Published var customArguments: String {
        didSet { defaults.set(customArguments, forKey: "customArguments") }
    }
    
    @Published var rateLimitKbps: Int {
        didSet { defaults.set(rateLimitKbps, forKey: "rateLimitKbps") }
    }
    
    @Published var clipboardMonitoring: Bool {
        didSet { defaults.set(clipboardMonitoring, forKey: "clipboardMonitoring") }
    }
    
    @Published var soundNotifications: Bool {
        didSet { defaults.set(soundNotifications, forKey: "soundNotifications") }
    }
    
    init() {
        let savedThemeString = defaults.string(forKey: "appTheme") ?? AppTheme.system.rawValue
        self.appTheme = AppTheme(rawValue: savedThemeString) ?? .system
        
        self.downloadDirectory = defaults.string(forKey: "downloadDirectory") ?? Constants.Paths.defaultDownloadDirectory.path
        self.defaultPresetId = defaults.string(forKey: "defaultPresetId") ?? DownloadPreset.bestVideo.id
        self.maxConcurrentDownloads = defaults.object(forKey: "maxConcurrentDownloads") != nil ? defaults.integer(forKey: "maxConcurrentDownloads") : 3
        self.autoCheckYtDlpUpdates = defaults.object(forKey: "autoCheckYtDlpUpdates") != nil ? defaults.bool(forKey: "autoCheckYtDlpUpdates") : true
        self.customYtDlpPath = defaults.string(forKey: "customYtDlpPath") ?? ""
        self.customFfmpegPath = defaults.string(forKey: "customFfmpegPath") ?? ""
        self.embedThumbnail = defaults.object(forKey: "embedThumbnail") != nil ? defaults.bool(forKey: "embedThumbnail") : true
        self.embedMetadata = defaults.object(forKey: "embedMetadata") != nil ? defaults.bool(forKey: "embedMetadata") : true
        self.embedChapters = defaults.object(forKey: "embedChapters") != nil ? defaults.bool(forKey: "embedChapters") : true
        self.embedSubtitles = defaults.bool(forKey: "embedSubtitles")
        self.subtitleLanguage = defaults.string(forKey: "subtitleLanguage") ?? "en"
        self.sponsorBlockEnabled = defaults.bool(forKey: "sponsorBlockEnabled")
        self.sponsorBlockCategories = defaults.string(forKey: "sponsorBlockCategories") ?? "sponsor,intro,outro,selfpromo"
        self.browserCookies = defaults.string(forKey: "browserCookies") ?? "none"
        self.customCookiesPath = defaults.string(forKey: "customCookiesPath") ?? ""
        self.filenameTemplate = defaults.string(forKey: "filenameTemplate") ?? "%(title)s [%(id)s].%(ext)s"
        self.customArguments = defaults.string(forKey: "customArguments") ?? ""
        self.rateLimitKbps = defaults.integer(forKey: "rateLimitKbps")
        self.clipboardMonitoring = defaults.object(forKey: "clipboardMonitoring") != nil ? defaults.bool(forKey: "clipboardMonitoring") : true
        self.soundNotifications = defaults.object(forKey: "soundNotifications") != nil ? defaults.bool(forKey: "soundNotifications") : true
        
        applyTheme()
    }
    
    var effectiveDownloadURL: URL {
        URL(fileURLWithPath: downloadDirectory)
    }
    
    func applyTheme() {
        DispatchQueue.main.async {
            switch self.appTheme {
            case .system:
                NSApp.appearance = nil
            case .light:
                NSApp.appearance = NSAppearance(named: .aqua)
            case .dark:
                NSApp.appearance = NSAppearance(named: .darkAqua)
            }
        }
    }
    
    func resetToDefaults() {
        appTheme = .system
        downloadDirectory = Constants.Paths.defaultDownloadDirectory.path
        defaultPresetId = DownloadPreset.bestVideo.id
        maxConcurrentDownloads = 3
        autoCheckYtDlpUpdates = true
        customYtDlpPath = ""
        customFfmpegPath = ""
        embedThumbnail = true
        embedMetadata = true
        embedChapters = true
        embedSubtitles = false
        subtitleLanguage = "en"
        sponsorBlockEnabled = false
        sponsorBlockCategories = "sponsor,intro,outro,selfpromo"
        browserCookies = "none"
        customCookiesPath = ""
        filenameTemplate = "%(title)s [%(id)s].%(ext)s"
        customArguments = ""
        rateLimitKbps = 0
        clipboardMonitoring = true
        soundNotifications = true
        applyTheme()
    }
}
