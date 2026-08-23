import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case engine = "Engine & Updates"
        case formats = "Formats & Media"
        case advanced = "Advanced"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .general: return "gear"
            case .engine: return "bolt"
            case .formats: return "film"
            case .advanced: return "slider.horizontal.3"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Selector
            HStack(spacing: 20) {
                ForEach(SettingsTab.allCases) { tab in
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16))
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                        }
                        .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Color.accentColor.opacity(0.12) : Color.clear)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            Divider()
            
            // Tab Contents
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .general:
                        generalSection
                    case .engine:
                        BinaryUpdaterView()
                        customPathsSection
                    case .formats:
                        formatsSection
                    case .advanced:
                        advancedSection
                    }
                }
                .padding(24)
            }
        }
        .frame(minWidth: 580, minHeight: 480)
    }
    
    // MARK: - General Section
    
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox(label: Label("Download Location", systemImage: "folder")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(settings.downloadDirectory)
                            .font(.system(size: 12, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button("Choose...") {
                            selectDownloadFolder()
                        }
                        
                        Button("Open") {
                            NSWorkspace.shared.open(URL(fileURLWithPath: settings.downloadDirectory))
                        }
                    }
                }
                .padding(8)
            }
            
            GroupBox(label: Label("Queue & Automation", systemImage: "arrow.triangle.swap")) {
                VStack(alignment: .leading, spacing: 12) {
                    Stepper("Max Concurrent Downloads: \(settings.maxConcurrentDownloads)", value: $settings.maxConcurrentDownloads, in: 1...10)
                        .font(.system(size: 13))
                    
                    Toggle("Monitor clipboard and detect media URLs", isOn: $settings.clipboardMonitoring)
                        .font(.system(size: 13))
                    
                    Toggle("Play sound & notify when download completes", isOn: $settings.soundNotifications)
                        .font(.system(size: 13))
                }
                .padding(8)
            }
        }
    }
    
    // MARK: - Custom Paths Section (Engine)
    
    private var customPathsSection: some View {
        GroupBox(label: Label("Custom Executable Paths", systemImage: "wrench.and.screwdriver")) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom yt-dlp binary path (optional):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        TextField("Leave blank to use managed or auto-detected binary", text: $settings.customYtDlpPath)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse...") {
                            selectFile(for: $settings.customYtDlpPath)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom FFmpeg binary path (optional):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        TextField("Leave blank to use system or Homebrew FFmpeg", text: $settings.customFfmpegPath)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse...") {
                            selectFile(for: $settings.customFfmpegPath)
                        }
                    }
                }
            }
            .padding(8)
        }
    }
    
    // MARK: - Formats Section
    
    private var formatsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox(label: Label("Default Quality Preset", systemImage: "sparkles")) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Default Preset", selection: $settings.defaultPresetId) {
                        ForEach(DownloadPreset.defaultPresets) { preset in
                            Text(preset.name).tag(preset.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(8)
            }
            
            GroupBox(label: Label("Filename Template", systemImage: "character.cursor.ibeam")) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Template", text: $settings.filenameTemplate)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                    
                    HStack(spacing: 8) {
                        Text("Presets:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("%(title)s.%(ext)s") {
                            settings.filenameTemplate = "%(title)s.%(ext)s"
                        }
                        .controlSize(.mini)
                        
                        Button("%(title)s [%(id)s].%(ext)s") {
                            settings.filenameTemplate = "%(title)s [%(id)s].%(ext)s"
                        }
                        .controlSize(.mini)
                        
                        Button("%(uploader)s - %(title)s.%(ext)s") {
                            settings.filenameTemplate = "%(uploader)s - %(title)s.%(ext)s"
                        }
                        .controlSize(.mini)
                    }
                }
                .padding(8)
            }
            
            GroupBox(label: Label("Metadata & Embedding", systemImage: "photo.artframe")) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Embed Thumbnail Artwork in downloaded files", isOn: $settings.embedThumbnail)
                    Toggle("Embed Metadata, Artist, and Tags", isOn: $settings.embedMetadata)
                    Toggle("Embed Chapters", isOn: $settings.embedChapters)
                    
                    HStack {
                        Toggle("Embed Subtitles by default", isOn: $settings.embedSubtitles)
                        if settings.embedSubtitles {
                            TextField("Sub language", text: $settings.subtitleLanguage)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                    }
                }
                .font(.system(size: 13))
                .padding(8)
            }
        }
    }
    
    // MARK: - Advanced Section
    
    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox(label: Label("Authentication & Cookies", systemImage: "lock.shield")) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Extract Cookies from Browser", selection: $settings.browserCookies) {
                        Text("None").tag("none")
                        Text("Safari").tag("safari")
                        Text("Google Chrome").tag("chrome")
                        Text("Firefox").tag("firefox")
                        Text("Brave").tag("brave")
                        Text("Microsoft Edge").tag("edge")
                    }
                    .pickerStyle(.menu)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Or use cookies.txt file:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            TextField("Path to cookies.txt", text: $settings.customCookiesPath)
                                .textFieldStyle(.roundedBorder)
                            Button("Browse...") {
                                selectFile(for: $settings.customCookiesPath)
                            }
                        }
                    }
                }
                .padding(8)
            }
            
            GroupBox(label: Label("SponsorBlock Integration", systemImage: "scissors")) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Enable SponsorBlock (skip/remove sponsored segments)", isOn: $settings.sponsorBlockEnabled)
                        .font(.system(size: 13))
                    
                    if settings.sponsorBlockEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Categories to remove (comma-separated):")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("sponsor,intro,outro,selfpromo,preview", text: $settings.sponsorBlockCategories)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                .padding(8)
            }
            
            GroupBox(label: Label("Power-User CLI Arguments", systemImage: "terminal")) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Global arguments appended to every yt-dlp command:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("--geo-bypass --no-check-certificates", text: $settings.customArguments)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                }
                .padding(8)
            }
            
            HStack {
                Spacer()
                Button(role: .destructive, action: {
                    settings.resetToDefaults()
                }) {
                    Label("Reset All Settings to Default", systemImage: "arrow.counterclockwise")
                }
                .controlSize(.regular)
            }
            .padding(.top, 10)
        }
    }
    
    // MARK: - Helpers
    
    private func selectDownloadFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select Download Folder"
        
        if panel.runModal() == .OK, let url = panel.url {
            settings.downloadDirectory = url.path
        }
    }
    
    private func selectFile(for binding: Binding<String>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select File"
        
        if panel.runModal() == .OK, let url = panel.url {
            binding.wrappedValue = url.path
        }
    }
}
