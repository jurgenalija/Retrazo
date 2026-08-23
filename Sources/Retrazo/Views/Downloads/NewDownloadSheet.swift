import SwiftUI
import AppKit

struct NewDownloadSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var queueManager = DownloadQueueManager.shared
    @ObservedObject var appState = AppState.shared
    @ObservedObject var settings = AppSettings.shared
    
    @State private var urlString: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var mediaInfo: MediaInfo? = nil
    @State private var analysisError: String? = nil
    
    // Preset and options
    @State private var selectedPreset: DownloadPreset = .bestVideo
    @State private var isCustomFormat: Bool = false
    @State private var selectedCustomFormatId: String = ""
    
    // Playlist options
    @State private var isPlaylistSelected: Bool = false
    @State private var playlistRange: String = ""
    
    // Advanced options accordion
    @State private var showAdvancedOptions: Bool = false
    @State private var embedThumbnail: Bool = true
    @State private var embedMetadata: Bool = true
    @State private var embedChapters: Bool = true
    @State private var embedSubtitles: Bool = false
    @State private var subtitleLang: String = "en"
    @State private var sponsorBlock: Bool = false
    @State private var customArgsText: String = ""
    
    init(prefillURL: String = "") {
        _urlString = State(initialValue: prefillURL)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Download")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // URL Input Section
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Media or Playlist URL")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            TextField("Paste URL here (YouTube, Vimeo, Twitter, TikTok, etc.)", text: $urlString)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 13))
                            
                            Button(action: {
                                if let clip = NSPasteboard.general.string(forType: .string) {
                                    urlString = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                                    analyzeURL()
                                }
                            }) {
                                Label("Paste", systemImage: "doc.on.clipboard")
                            }
                            
                            Button(action: analyzeURL) {
                                if isAnalyzing {
                                    ProgressView()
                                        .controlSize(.small)
                                        .frame(width: 55)
                                } else {
                                    Text("Analyze")
                                        .frame(width: 55)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(urlString.trimmingCharacters(in: .whitespaces).isEmpty || isAnalyzing)
                        }
                    }
                    
                    // Analysis Error
                    if let error = analysisError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(10)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    // Analyzed Media Preview
                    if let info = mediaInfo {
                        mediaPreviewCard(info)
                    }
                    
                    // Format & Preset Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quality & Format Preset")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 8) {
                            ForEach(DownloadPreset.defaultPresets) { preset in
                                presetButton(preset)
                            }
                        }
                    }
                    
                    // Custom Format Picker (if formats available)
                    if let formats = mediaInfo?.parsedFormats, !formats.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Select Specific Stream / Format ID", isOn: $isCustomFormat)
                                .font(.system(size: 12, weight: .medium))
                            
                            if isCustomFormat {
                                Picker("Format Stream", selection: $selectedCustomFormatId) {
                                    Text("Auto Best").tag("")
                                    ForEach(formats) { fmt in
                                        Text("\(fmt.formatId): \(fmt.displayTitle)").tag(fmt.formatId)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        .padding(10)
                        .background(Color.secondary.opacity(0.06))
                        .cornerRadius(8)
                    }
                    
                    // Playlist Section
                    if mediaInfo?.isPlaylist == true {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Playlist Options", systemImage: "list.bullet")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            HStack {
                                TextField("Playlist Range (e.g. 1-10, 5, 8-12) - leave empty for all", text: $playlistRange)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        .padding(10)
                        .background(Color.secondary.opacity(0.06))
                        .cornerRadius(8)
                    }
                    
                    // Advanced Options Accordion
                    DisclosureGroup("Advanced Options", isExpanded: $showAdvancedOptions) {
                        VStack(alignment: .leading, spacing: 12) {
                            // Toggles
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle("Embed Thumbnail / Cover Art", isOn: $embedThumbnail)
                                Toggle("Embed Metadata & Tags", isOn: $embedMetadata)
                                Toggle("Embed Chapter Markers", isOn: $embedChapters)
                                
                                HStack {
                                    Toggle("Embed Subtitles", isOn: $embedSubtitles)
                                    if embedSubtitles {
                                        TextField("Languages (e.g. en, es, ja or 'all')", text: $subtitleLang)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 160)
                                    }
                                }
                                
                                Toggle("SponsorBlock (Remove sponsored segments)", isOn: $sponsorBlock)
                            }
                            .font(.system(size: 12))
                            
                            // Custom CLI arguments
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Extra yt-dlp arguments:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("--geo-bypass --no-check-certificates", text: $customArgsText)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12, design: .monospaced))
                            }
                        }
                        .padding(.top, 8)
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer Action Bar
            HStack {
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                
                Button(action: startDownload) {
                    Label("Start Download", systemImage: "arrow.down.circle.fill")
                        .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .disabled(urlString.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 540, maxWidth: 640, minHeight: 480, maxHeight: 680)
        .onAppear {
            embedThumbnail = settings.embedThumbnail
            embedMetadata = settings.embedMetadata
            embedChapters = settings.embedChapters
            embedSubtitles = settings.embedSubtitles
            subtitleLang = settings.subtitleLanguage
            sponsorBlock = settings.sponsorBlockEnabled
            
            if let defaultP = DownloadPreset.defaultPresets.first(where: { $0.id == settings.defaultPresetId }) {
                selectedPreset = defaultP
            }
            
            if !urlString.isEmpty {
                analyzeURL()
            }
        }
    }
    
    // MARK: - Subviews
    
    private func presetButton(_ preset: DownloadPreset) -> some View {
        let isSelected = selectedPreset.id == preset.id && !isCustomFormat
        return Button(action: {
            selectedPreset = preset
            isCustomFormat = false
        }) {
            HStack(spacing: 6) {
                Image(systemName: preset.type.icon)
                    .font(.system(size: 11))
                Text(preset.name)
                    .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    private func mediaPreviewCard(_ info: MediaInfo) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let thumb = info.thumbnail, let url = URL(string: thumb) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.secondary.opacity(0.15)
                }
                .frame(width: 90, height: 60)
                .cornerRadius(6)
                .clipped()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(info.displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text(info.displayUploader)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !info.formattedDuration.isEmpty {
                        Text("• \(info.formattedDuration)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if info.isPlaylist {
                        Text("• Playlist (\(info.playlistCount ?? info.entries?.count ?? 0) items)")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            Spacer()
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
    }
    
    // MARK: - Actions
    
    private func analyzeURL() {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        isAnalyzing = true
        analysisError = nil
        
        Task {
            do {
                let info = try await YtDlpProcessManager.shared.fetchMediaInfo(url: trimmed)
                await MainActor.run {
                    self.mediaInfo = info
                    self.isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    self.analysisError = error.localizedDescription
                    self.isAnalyzing = false
                }
            }
        }
    }
    
    private func startDownload() {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var customArgs: [String] = []
        
        if isCustomFormat && !selectedCustomFormatId.isEmpty {
            customArgs.append(contentsOf: ["-f", selectedCustomFormatId])
        }
        
        if !playlistRange.trimmingCharacters(in: .whitespaces).isEmpty {
            customArgs.append(contentsOf: ["--playlist-items", playlistRange.trimmingCharacters(in: .whitespaces)])
        }
        
        if embedSubtitles {
            customArgs.append(contentsOf: ["--embed-subs", "--sub-langs", subtitleLang])
        }
        
        if sponsorBlock {
            customArgs.append(contentsOf: ["--sponsorblock-remove", "sponsor,intro,outro,selfpromo"])
        }
        
        if !customArgsText.trimmingCharacters(in: .whitespaces).isEmpty {
            let split = customArgsText.split(separator: " ").map(String.init)
            customArgs.append(contentsOf: split)
        }
        
        queueManager.enqueue(
            url: trimmed,
            preset: selectedPreset,
            customArgs: customArgs,
            mediaInfo: mediaInfo
        )
        
        appState.quickURLText = ""
        dismiss()
    }
}
