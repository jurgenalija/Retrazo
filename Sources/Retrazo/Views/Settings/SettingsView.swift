import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    let selectedTab: SettingsTab
    @State private var archiveMessage: String? = nil
    
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
        .frame(minWidth: 580, minHeight: 480)
    }
    
    // MARK: - General Section
    
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            // macOS Native Appearance Card Selector
            GroupBox(label: Label("Appearance", systemImage: "paintbrush")) {
                HStack(spacing: 20) {
                    ForEach(AppTheme.allCases) { theme in
                        ThemeOptionCard(
                            theme: theme,
                            isSelected: settings.appTheme == theme,
                            onSelect: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    settings.appTheme = theme
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
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

            GroupBox(label: Label("Duplicate Prevention", systemImage: "checkmark.circle")) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Skip media downloaded previously", isOn: $settings.skipPreviouslyDownloaded)
                        .font(.system(size: 13))

                    Text("Retrazo records successful downloads and skips matching media in the future.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Button("Clear Download Archive") {
                            clearDownloadArchive()
                        }
                        .disabled(!FileManager.default.fileExists(atPath: Constants.Paths.downloadArchiveFile.path))

                        if let archiveMessage {
                            Text(archiveMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
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

    private func clearDownloadArchive() {
        do {
            if FileManager.default.fileExists(atPath: Constants.Paths.downloadArchiveFile.path) {
                try FileManager.default.removeItem(at: Constants.Paths.downloadArchiveFile)
            }
            archiveMessage = "Archive cleared"
        } catch {
            archiveMessage = "Could not clear archive"
        }
    }
}

// MARK: - ThemeOptionCard (Clean macOS Visual Preview Card)

struct ThemeOptionCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                // Mini Window Preview
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isSelected ? Color.accentColor : (isHovered ? Color.secondary.opacity(0.45) : Color.secondary.opacity(0.2)),
                            lineWidth: isSelected ? 2 : 1
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                    
                    previewIllustration
                        .cornerRadius(5)
                        .padding(2)
                }
                .frame(width: 86, height: 56)
                .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : (isHovered ? Color.black.opacity(0.1) : Color.clear), radius: 4, x: 0, y: 2)
                
                // Label with active check indicator
                HStack(spacing: 4) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.accentColor)
                    }
                    Text(theme.rawValue)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .primary : .secondary)
                }
            }
            .padding(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    @ViewBuilder
    private var previewIllustration: some View {
        switch theme {
        case .light:
            VStack(spacing: 3) {
                HStack(spacing: 3) {
                    Circle().fill(Color.red.opacity(0.8)).frame(width: 4, height: 4)
                    Circle().fill(Color.yellow.opacity(0.8)).frame(width: 4, height: 4)
                    Circle().fill(Color.green.opacity(0.8)).frame(width: 4, height: 4)
                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)
                
                VStack(alignment: .leading, spacing: 3) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.3)).frame(height: 5)
                    RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.2)).frame(width: 48, height: 4)
                    RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.2)).frame(width: 32, height: 4)
                }
                .padding(.horizontal, 4)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            
        case .dark:
            VStack(spacing: 3) {
                HStack(spacing: 3) {
                    Circle().fill(Color.red.opacity(0.8)).frame(width: 4, height: 4)
                    Circle().fill(Color.yellow.opacity(0.8)).frame(width: 4, height: 4)
                    Circle().fill(Color.green.opacity(0.8)).frame(width: 4, height: 4)
                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.top, 4)
                
                VStack(alignment: .leading, spacing: 3) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.35)).frame(height: 5)
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.2)).frame(width: 48, height: 4)
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.2)).frame(width: 32, height: 4)
                }
                .padding(.horizontal, 4)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.12, green: 0.12, blue: 0.15))
            
        case .system:
            HStack(spacing: 0) {
                // Left half: Light
                VStack(spacing: 3) {
                    HStack(spacing: 2) {
                        Circle().fill(Color.red.opacity(0.8)).frame(width: 4, height: 4)
                        Circle().fill(Color.yellow.opacity(0.8)).frame(width: 4, height: 4)
                        Spacer()
                    }
                    .padding(.leading, 3)
                    .padding(.top, 4)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.3)).frame(height: 5)
                        RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.2)).frame(width: 22, height: 4)
                    }
                    .padding(.leading, 3)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                
                // Divider line
                Rectangle().fill(Color.gray.opacity(0.35)).frame(width: 1)
                
                // Right half: Dark
                VStack(spacing: 3) {
                    HStack {
                        Spacer()
                        Circle().fill(Color.green.opacity(0.8)).frame(width: 4, height: 4)
                    }
                    .padding(.trailing, 3)
                    .padding(.top, 4)
                    
                    VStack(alignment: .trailing, spacing: 3) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.35)).frame(height: 5)
                        RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.2)).frame(width: 22, height: 4)
                    }
                    .padding(.trailing, 3)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.12, green: 0.12, blue: 0.15))
            }
        }
    }
}
