import SwiftUI
import AppKit

enum DownloadSheetTab: String, CaseIterable, Identifiable {
    case video = "Video"
    case audio = "Audio"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .video: return "video.fill"
        case .audio: return "music.note"
        }
    }
}

private enum PlaylistDownloadMode: String, CaseIterable, Identifiable {
    case singleVideo = "This Video Only"
    case entirePlaylist = "Entire Playlist"

    var id: String { rawValue }
}

private enum SubtitleDownloadMode: String, CaseIterable, Identifiable {
    case none = "None"
    case embed = "Embed in Media"
    case separate = "Separate Files"

    var id: String { rawValue }
}

struct NewDownloadSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var queueManager = DownloadQueueManager.shared
    @ObservedObject var appState = AppState.shared
    @ObservedObject var settings = AppSettings.shared

    @State private var urlString: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var mediaInfo: MediaInfo? = nil
    @State private var analysisError: String? = nil
    @State private var analyzedURL: String = ""
    @State private var analysisRequestedURL: String = ""
    @State private var analysisTask: Task<Void, Never>? = nil

    // Tab selection
    @State private var selectedTab: DownloadSheetTab = .video

    // Video configuration
    @State private var selectedVideoContainer: VideoContainer = .mp4
    @State private var selectedQualityHeight: Int? = nil // nil = source maximum when exact qualities are unavailable

    // Audio configuration
    @State private var selectedAudioFormat: AudioFormat = .mp3
    @State private var selectedAudioQuality: AudioQuality = .kbps320

    // Custom stream selection
    @State private var selectedCustomFormatId: String = ""

    // Playlist options
    @State private var playlistMode: PlaylistDownloadMode = .singleVideo
    @State private var playlistRange: String = ""

    // Advanced options accordion
    @State private var showAdvancedOptions: Bool = false
    @State private var embedThumbnail: Bool = true
    @State private var embedMetadata: Bool = true
    @State private var embedChapters: Bool = true
    @State private var splitChapters: Bool = false
    @State private var subtitleMode: SubtitleDownloadMode = .none
    @State private var subtitleLang: String = "en"
    @State private var includeAutomaticSubtitles: Bool = false
    @State private var convertSubtitlesToSRT: Bool = false
    @State private var limitToTimeRange: Bool = false
    @State private var rangeStart: String = ""
    @State private var rangeEnd: String = ""
    @State private var sponsorBlock: Bool = false
    @State private var customArgsText: String = ""

    init(prefillURL: String = "") {
        _urlString = State(initialValue: prefillURL)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // URL Input Section
                    urlInputSection

                    // Analysis Spinner Banner
                    if isAnalyzing {
                        analyzingBanner
                    }

                    // Analysis Error
                    if let error = analysisError {
                        analysisErrorBanner(error)
                    }

                    if let info = mediaInfo {
                        mediaPreviewCard(info)

                        typeSelectorTabs

                        switch selectedTab {
                        case .video:
                            videoOptionsSection
                        case .audio:
                            audioOptionsSection
                        }

                        if hasPlaylistContext {
                            playlistSection
                        }
                    } else if !isAnalyzing {
                        linkRequiredCard
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer Action Bar
            footerActionBar
        }
        .frame(minWidth: 620, maxWidth: 700, minHeight: 560, maxHeight: 780)
        .onAppear {
            loadInitialSettings()
            if !urlString.isEmpty {
                analyzeURL()
            }
        }
        .onChange(of: urlString) { newValue in
            let normalized = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if isAnalyzing && normalized != analysisRequestedURL {
                analysisTask?.cancel()
                analysisTask = nil
                analysisRequestedURL = ""
                isAnalyzing = false
            }
            if !analyzedURL.isEmpty && normalized != analyzedURL {
                mediaInfo = nil
                analyzedURL = ""
                analysisError = nil
            }
        }
        .onDisappear {
            analysisTask?.cancel()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "arrow.down.to.line.circle.fill")
                .foregroundColor(.accentColor)
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 2) {
                Text("Download options")
                    .font(.headline)

                Text("Check the source, choose a format, then download.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isAnalyzing {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                showAdvancedOptions = true
            } label: {
                Label("Advanced Options", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
            .popover(isPresented: $showAdvancedOptions, arrowEdge: .top) {
                advancedOptionsPanel
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - URL Section

    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionTitle(number: "1", title: "Add a link")

                Spacer()

                if mediaInfo != nil {
                    Label("Source checked", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.secondary)

                    TextField("Paste a video or playlist link", text: $urlString)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .onSubmit {
                            if urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                pasteLinkAndAnalyze()
                            } else {
                                analyzeURL()
                            }
                        }

                    if !urlString.isEmpty {
                        Button(action: {
                            urlString = ""
                            mediaInfo = nil
                            analysisError = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Button(action: urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? pasteLinkAndAnalyze : analyzeURL) {
                    if isAnalyzing {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 94)
                    } else {
                        Label(
                            urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Paste Link" : (mediaInfo == nil ? "Check Link" : "Recheck"),
                            systemImage: urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "doc.on.clipboard" : "checkmark.shield"
                        )
                        .frame(minWidth: 94)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isAnalyzing)
            }
        }
    }

    // MARK: - Banner Views

    private var analyzingBanner: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Checking the source and finding its available qualities…")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08))
        .cornerRadius(6)
    }

    private var linkRequiredCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 22))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 3) {
                Text("Qualities appear after the link is checked")
                    .font(.system(size: 13, weight: .semibold))

                Text("Retrazo will never offer a resolution higher than the source provides.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func analysisErrorBanner(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(error)
                .font(.caption)
                .foregroundColor(.red)

            Spacer()

            if !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("Try Again", action: analyzeURL)
                    .controlSize(.small)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .cornerRadius(6)
    }

    // MARK: - Media Preview Card

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
                .frame(width: 100, height: 65)
                .cornerRadius(6)
                .clipped()
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(info.displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)

                HStack(spacing: 6) {
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

                // Detected Quality Badge Row
                HStack(spacing: 6) {
                    if let maxQ = info.maxDetectedQuality {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10))
                            Text("Highest available: \(maxQ.label)")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(4)

                    } else if info.isPlaylist {
                        Text("Quality is chosen per playlist item")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
    }

    // MARK: - Type Selector Tabs

    private var typeSelectorTabs: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(number: "2", title: "Choose what to download")

            Picker("Download type", selection: $selectedTab) {
                ForEach(DownloadSheetTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // MARK: - Video Options Section

    private var videoOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    optionTitle("Resolution")

                    Spacer()

                    if let maxH = mediaInfo?.maxDetectedHeight {
                        Label("Source maximum \(maxH)p", systemImage: "checkmark.shield.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                if let detected = mediaInfo?.detectedVideoQualities, !detected.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(detected) { quality in
                            let isSourceMaximum = quality.height == mediaInfo?.maxDetectedHeight
                            let isSelected = selectedQualityHeight == quality.height
                            qualitySelectionRow(
                                title: quality.label,
                                subtitle: isSourceMaximum ? "Highest resolution provided by this source" : "Download at up to \(quality.height)p",
                                badge: isSourceMaximum ? "SOURCE MAX" : nil,
                                size: quality.formattedSize,
                                isSelected: isSelected,
                                onSelect: { selectedQualityHeight = quality.height }
                            )
                        }
                    }
                } else if mediaInfo?.isPlaylist == true {
                    qualitySelectionRow(
                        title: "Maximum available for each video",
                        subtitle: "Playlist items may have different source resolutions",
                        badge: "PLAYLIST",
                        size: nil,
                        isSelected: selectedQualityHeight == nil,
                        onSelect: { selectedQualityHeight = nil }
                    )
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Exact resolution details are unavailable")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Retrazo will use the source's native maximum without upscaling.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                optionTitle("File type")

                HStack(spacing: 8) {
                    ForEach(VideoContainer.allCases) { container in
                        let isSelected = selectedVideoContainer == container
                        Button {
                            selectedVideoContainer = container
                        } label: {
                            VStack(spacing: 2) {
                                Text(container.displayName)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(containerDescription(container))
                                    .font(.system(size: 9))
                                    .foregroundColor(isSelected ? .accentColor : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func qualitySelectionRow(
        title: String,
        subtitle: String?,
        badge: String?,
        size: String?,
        isSelected: Bool,
        onSelect: @escaping () -> Void
    ) -> some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(.primary)

                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .cornerRadius(3)
                        }
                    }

                    if let sub = subtitle {
                        Text(sub)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if let size = size {
                    Text(size)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Audio Options Section

    private var audioOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                optionTitle("Audio format")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                    ForEach(AudioFormat.allCases) { format in
                        let isSelected = selectedAudioFormat == format
                        Button(action: {
                            selectedAudioFormat = format
                        }) {
                            Text(format.displayName)
                                .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                                .foregroundColor(isSelected ? .white : .primary)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                optionTitle("Audio quality")

                HStack(spacing: 8) {
                    ForEach(AudioQuality.allCases) { quality in
                        let isSelected = selectedAudioQuality == quality
                        Button(action: {
                            selectedAudioQuality = quality
                        }) {
                            Text(quality == .best ? "Highest" : quality.rawValue)
                                .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                                .foregroundColor(isSelected ? .accentColor : .primary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                                )
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Playlist Section

    private var playlistSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Playlist Options", systemImage: "list.bullet")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)

            if canChooseVideoOrPlaylist {
                Picker("Download", selection: $playlistMode) {
                    ForEach(PlaylistDownloadMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            } else {
                Label("Entire Playlist", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.accentColor)
            }

            if playlistMode == .entirePlaylist {
                TextField("Playlist Range (e.g. 1-10, 5, 8-12) - leave empty for all", text: $playlistRange)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(8)
    }

    // MARK: - Advanced Options Popover

    private var advancedOptionsPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Advanced Options", systemImage: "slider.horizontal.3")
                    .font(.headline)

                Spacer()

                Button {
                    showAdvancedOptions = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close Advanced Options")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Download a Time Range", isOn: $limitToTimeRange)

                        if limitToTimeRange {
                            HStack(spacing: 8) {
                                TextField("Start (e.g. 01:20)", text: $rangeStart)
                                    .textFieldStyle(.roundedBorder)
                                Text("to")
                                    .foregroundColor(.secondary)
                                TextField("End (e.g. 04:45)", text: $rangeEnd)
                                    .textFieldStyle(.roundedBorder)
                            }

                            if let message = timeRangeValidationMessage {
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    Divider()

                    // Toggles
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Embed Thumbnail / Cover Art", isOn: $embedThumbnail)
                        Toggle("Embed Metadata & Tags", isOn: $embedMetadata)
                        Toggle("Embed Chapter Markers", isOn: $embedChapters)

                        VStack(alignment: .leading, spacing: 2) {
                            Toggle("Split Chapters", isOn: $splitChapters)
                            Text("Creates a separate file for each chapter when chapter markers are available.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)
                        }

                        VStack(alignment: .leading, spacing: 7) {
                            Picker("Subtitles", selection: $subtitleMode) {
                                ForEach(SubtitleDownloadMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

                            if subtitleMode != .none {
                                TextField("Languages (e.g. en, es, ja or 'all')", text: $subtitleLang)
                                    .textFieldStyle(.roundedBorder)

                                HStack(spacing: 16) {
                                    Toggle("Include auto-generated subtitles", isOn: $includeAutomaticSubtitles)
                                    Toggle("Convert to SRT", isOn: $convertSubtitlesToSRT)
                                }
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

                    if let formats = mediaInfo?.parsedFormats, !formats.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 5) {
                            Text("Source stream override")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Picker("Source stream override", selection: $selectedCustomFormatId) {
                                Text("Automatic (Recommended)").tag("")
                                ForEach(formats) { format in
                                    Text("\(format.formatId): \(format.displayTitle)").tag(format.formatId)
                                }
                            }
                            .pickerStyle(.menu)

                            Text("For advanced users who need a specific yt-dlp format ID.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 480, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
        .font(.system(size: 12, weight: .medium))
    }

    // MARK: - Footer Action Bar

    private var footerActionBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(footerStatusTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(canStartDownload ? .primary : .secondary)

                Text(currentSelectionSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("Cancel") {
                dismiss()
            }

            Button(action: startDownload) {
                Label(downloadButtonTitle, systemImage: "arrow.down.circle.fill")
                    .frame(minWidth: 165)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canStartDownload)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var currentSelectionSummary: String {
        let scope = hasPlaylistContext && playlistMode == .entirePlaylist ? " • Entire playlist" : ""
        switch selectedTab {
        case .video:
            let quality = selectedQualityHeight.map { "\($0)p" }
                ?? (mediaInfo?.isPlaylist == true ? "Maximum per playlist item" : "Source maximum")
            return "\(quality) • \(selectedVideoContainer.displayName) video\(scope)"
        case .audio:
            let quality = selectedAudioQuality == .best ? "Highest source quality" : selectedAudioQuality.rawValue
            return "\(selectedAudioFormat.displayName) audio • \(quality)\(scope)"
        }
    }

    private var downloadButtonTitle: String {
        if hasPlaylistContext && playlistMode == .entirePlaylist {
            return "Download Playlist"
        }

        switch selectedTab {
        case .video:
            if let height = selectedQualityHeight {
                return "Download \(height)p"
            }
            return mediaInfo?.isPlaylist == true ? "Download Playlist" : "Download Source"
        case .audio:
            return "Download \(selectedAudioFormat.displayName)"
        }
    }

    private var canStartDownload: Bool {
        guard mediaInfo != nil, !isAnalyzing else { return false }
        guard !limitToTimeRange || timeRangeValidationMessage == nil else { return false }
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host != nil else { return false }
        return true
    }

    private var footerStatusTitle: String {
        if limitToTimeRange, timeRangeValidationMessage != nil {
            return "Enter a valid time range"
        }
        return canStartDownload ? "Ready to download" : "Check a link to continue"
    }

    private var hasPlaylistContext: Bool {
        if mediaInfo?.isPlaylist == true {
            return true
        }
        return URLComponents(string: urlString)?.queryItems?.contains {
            $0.name.lowercased() == "list" && !($0.value ?? "").isEmpty
        } == true
    }

    private var canChooseVideoOrPlaylist: Bool {
        guard hasPlaylistContext, mediaInfo?.isPlaylist != true,
              let components = URLComponents(string: urlString) else { return false }

        if components.queryItems?.contains(where: {
            $0.name.lowercased() == "v" && !($0.value ?? "").isEmpty
        }) == true {
            return true
        }

        let host = components.host?.lowercased() ?? ""
        return (host == "youtu.be" || host.hasSuffix(".youtu.be")) && components.path.count > 1
    }

    private var timeRangeValidationMessage: String? {
        guard limitToTimeRange else { return nil }
        guard let start = timestampSeconds(rangeStart), let end = timestampSeconds(rangeEnd) else {
            return "Use SS, MM:SS, or HH:MM:SS for both times."
        }
        guard end > start else {
            return "The end time must be later than the start time."
        }
        return nil
    }

    private func timestampSeconds(_ value: String) -> Int? {
        let parts = value.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        let numbers = parts.compactMap { Int($0) }
        guard (1...3).contains(parts.count), numbers.count == parts.count,
              numbers.allSatisfy({ $0 >= 0 }) else { return nil }

        if numbers.count > 1, numbers.last! >= 60 {
            return nil
        }
        if numbers.count == 3, numbers[1] >= 60 {
            return nil
        }

        switch numbers.count {
        case 1: return numbers[0]
        case 2: return numbers[0] * 60 + numbers[1]
        case 3: return numbers[0] * 3600 + numbers[1] * 60 + numbers[2]
        default: return nil
        }
    }

    private func sectionTitle(number: String, title: String) -> some View {
        HStack(spacing: 7) {
            Text(number)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Color.accentColor)
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 13, weight: .semibold))
        }
    }

    private func optionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
    }

    private func containerDescription(_ container: VideoContainer) -> String {
        switch container {
        case .mp4: return "Compatible"
        case .mkv: return "Flexible"
        case .webm: return "Web"
        case .mov: return "Apple"
        }
    }

    // MARK: - Initial Setup

    private func loadInitialSettings() {
        embedThumbnail = settings.embedThumbnail
        embedMetadata = settings.embedMetadata
        embedChapters = settings.embedChapters
        subtitleMode = settings.embedSubtitles ? .embed : .none
        subtitleLang = settings.subtitleLanguage
        sponsorBlock = settings.sponsorBlockEnabled

        if let defaultP = DownloadPreset.defaultPresets.first(where: { $0.id == settings.defaultPresetId }) {
            if defaultP.extractAudio {
                selectedTab = .audio
                selectedAudioFormat = defaultP.audioFormat
                selectedAudioQuality = defaultP.audioQuality
            } else {
                selectedTab = .video
                selectedVideoContainer = defaultP.videoContainer
                selectedQualityHeight = defaultP.customMaxHeight ?? defaultP.videoQuality.maxHeight
            }
        }
    }

    // MARK: - Actions

    private func pasteLinkAndAnalyze() {
        guard let clipboardText = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !clipboardText.isEmpty else {
            analysisError = "Copy a media link to the clipboard, then try again."
            return
        }

        urlString = clipboardText
        analyzeURL()
    }

    private func analyzeURL() {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        analysisTask?.cancel()
        analysisTask = nil
        analysisRequestedURL = ""
        isAnalyzing = false

        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host != nil else {
            mediaInfo = nil
            analyzedURL = ""
            analysisError = "Enter a complete web URL beginning with http:// or https://."
            return
        }

        isAnalyzing = true
        analysisRequestedURL = trimmed
        mediaInfo = nil
        analyzedURL = ""
        analysisError = nil

        analysisTask = Task {
            do {
                let info = try await YtDlpProcessManager.shared.fetchMediaInfo(url: trimmed)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self.urlString.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed else { return }
                    self.mediaInfo = info
                    self.analyzedURL = trimmed
                    self.analysisRequestedURL = ""
                    self.isAnalyzing = false
                    self.playlistMode = info.isPlaylist ? .entirePlaylist : .singleVideo

                    let availableHeights = info.detectedVideoQualities.map(\.height)
                    if info.isPlaylist || availableHeights.isEmpty {
                        self.selectedQualityHeight = nil
                    } else if let currentHeight = self.selectedQualityHeight,
                              availableHeights.contains(currentHeight) {
                        // Keep the user's preferred cap when the source actually offers it.
                    } else if let currentHeight = self.selectedQualityHeight,
                              let nearestAvailable = availableHeights.first(where: { $0 <= currentHeight }) {
                        self.selectedQualityHeight = nearestAvailable
                    } else {
                        // No ambiguous "Best" choice: select the exact source maximum.
                        self.selectedQualityHeight = availableHeights.first
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self.urlString.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed else { return }
                    self.analysisError = error.localizedDescription
                    self.analysisRequestedURL = ""
                    self.isAnalyzing = false
                }
            }
        }
    }

    private func startDownload() {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !limitToTimeRange || timeRangeValidationMessage == nil else {
            analysisError = timeRangeValidationMessage
            return
        }
        guard mediaInfo != nil else {
            analysisError = "Check the link before starting the download."
            return
        }

        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host != nil else {
            analysisError = "Enter a complete web URL beginning with http:// or https://."
            return
        }

        var customArgs: [String] = []

        // Build preset according to active tab
        let activePreset: DownloadPreset

        switch selectedTab {
        case .video:
            if let h = selectedQualityHeight {
                let vq = VideoQuality.forHeight(h)
                activePreset = DownloadPreset(
                    id: "video-\(h)p-\(selectedVideoContainer.rawValue)",
                    name: "\(h)p (\(selectedVideoContainer.displayName))",
                    type: .video,
                    videoQuality: vq,
                    customMaxHeight: h,
                    videoContainer: selectedVideoContainer,
                    audioFormat: .m4a,
                    audioQuality: .best,
                    extractAudio: false
                )
            } else {
                activePreset = DownloadPreset.bestVideo(
                    container: selectedVideoContainer,
                    maxQuality: mediaInfo?.maxDetectedQuality
                )
            }

        case .audio:
            let audioQualityName = selectedAudioQuality == .best ? "Highest" : selectedAudioQuality.rawValue
            activePreset = DownloadPreset(
                id: "audio-\(selectedAudioFormat.rawValue)-\(selectedAudioQuality.rawValue)",
                name: "\(selectedAudioFormat.displayName) Audio (\(audioQualityName))",
                type: .audio,
                videoQuality: .best,
                videoContainer: .mp4,
                audioFormat: selectedAudioFormat,
                audioQuality: selectedAudioQuality,
                extractAudio: true
            )

        }

        if !selectedCustomFormatId.isEmpty {
            customArgs.append(contentsOf: ["-f", selectedCustomFormatId])
        }

        if hasPlaylistContext && playlistMode == .entirePlaylist {
            customArgs.append("--yes-playlist")
        } else {
            customArgs.append("--no-playlist")
        }

        if playlistMode == .entirePlaylist,
           !playlistRange.trimmingCharacters(in: .whitespaces).isEmpty {
            customArgs.append(contentsOf: ["--playlist-items", playlistRange.trimmingCharacters(in: .whitespaces)])
        }

        if limitToTimeRange, timeRangeValidationMessage == nil {
            let start = rangeStart.trimmingCharacters(in: .whitespacesAndNewlines)
            let end = rangeEnd.trimmingCharacters(in: .whitespacesAndNewlines)
            customArgs.append(contentsOf: ["--download-sections", "*\(start)-\(end)"])
        }

        if subtitleMode != .none {
            let language = subtitleLang.trimmingCharacters(in: .whitespacesAndNewlines)
            customArgs.append(contentsOf: ["--write-subs", "--sub-langs", language.isEmpty ? "all" : language])

            if includeAutomaticSubtitles {
                customArgs.append("--write-auto-subs")
            }
            if convertSubtitlesToSRT {
                customArgs.append(contentsOf: ["--convert-subs", "srt"])
            }
        }

        if !customArgsText.trimmingCharacters(in: .whitespaces).isEmpty {
            let split = customArgsText.split(separator: " ").map(String.init)
            customArgs.append(contentsOf: split)
        }

        queueManager.enqueue(
            url: trimmed,
            preset: activePreset,
            customArgs: customArgs,
            mediaInfo: mediaInfo,
            optionOverrides: DownloadOptionOverrides(
                embedThumbnail: embedThumbnail,
                embedMetadata: embedMetadata,
                embedChapters: embedChapters,
                embedSubtitles: subtitleMode == .embed,
                subtitleLanguage: subtitleLang.trimmingCharacters(in: .whitespacesAndNewlines),
                sponsorBlockEnabled: sponsorBlock,
                splitChapters: splitChapters
            )
        )

        appState.quickURLText = ""
        dismiss()
    }
}
