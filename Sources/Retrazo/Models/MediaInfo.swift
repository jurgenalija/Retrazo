import Foundation

struct MediaSubtitle: Codable, Hashable {
    let ext: String?
    let url: String?
    let name: String?
}

struct MediaChapter: Codable, Hashable {
    let title: String?
    let startTime: Double?
    let endTime: Double?

    enum CodingKeys: String, CodingKey {
        case title
        case startTime = "start_time"
        case endTime = "end_time"
    }
}

struct PlaylistEntry: Codable, Identifiable, Hashable {
    var id: String
    let title: String?
    let url: String?
    let duration: Double?
    let uploader: String?
    let thumbnail: String?
    let ieKey: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case url
        case duration
        case uploader
        case thumbnail
        case ieKey = "ie_key"
    }
}

struct DetectedQuality: Identifiable, Hashable, Codable {
    var id: String { "\(height)p\(fps > 30 ? "_\(Int(round(fps)))fps" : "")\(hasHdr ? "_hdr" : "")" }
    let height: Int
    let width: Int?
    let fps: Double
    let hasHdr: Bool
    let formatNote: String?
    let filesize: Int64?
    let filesizeApprox: Int64?
    let videoQuality: VideoQuality

    var label: String {
        var res = ""
        switch height {
        case 4320...: res = "8K (4320p)"
        case 2160...4319: res = "4K (2160p)"
        case 1440...2159: res = "2K (1440p)"
        case 1080...1439: res = "1080p (Full HD)"
        case 720...1079: res = "720p (HD)"
        case 480...719: res = "480p (SD)"
        case 360...479: res = "360p"
        case 240...359: res = "240p"
        case 144...239: res = "144p"
        default: res = "\(height)p"
        }

        if fps > 30 {
            res += " \(Int(round(fps)))fps"
        }
        if hasHdr {
            res += " HDR"
        }
        return res
    }

    var resolutionBadge: String {
        var str = "\(height)p"
        if fps > 30 {
            str += "\(Int(round(fps)))"
        }
        if hasHdr {
            str += " HDR"
        }
        return str
    }

    var formattedSize: String? {
        let bytes = filesize ?? filesizeApprox
        guard let b = bytes, b > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: b, countStyle: .file)
    }
}

struct MediaInfo: Codable, Identifiable {
    var id: String
    let title: String?
    let description: String?
    let uploader: String?
    let uploaderUrl: String?
    let channel: String?
    let duration: Double?
    let thumbnail: String?
    let webpageUrl: String?
    let viewCount: Int?
    let formats: [RawFormat]?
    let subtitles: [String: [MediaSubtitle]]?
    let automaticCaptions: [String: [MediaSubtitle]]?
    let chapters: [MediaChapter]?
    let playlistTitle: String?
    let playlistId: String?
    let playlistCount: Int?
    let entries: [PlaylistEntry]?
    let isLive: Bool?
    let height: Int?
    let width: Int?
    let resolution: String?

    init(
        id: String,
        title: String? = nil,
        description: String? = nil,
        uploader: String? = nil,
        uploaderUrl: String? = nil,
        channel: String? = nil,
        duration: Double? = nil,
        thumbnail: String? = nil,
        webpageUrl: String? = nil,
        viewCount: Int? = nil,
        formats: [RawFormat]? = nil,
        subtitles: [String: [MediaSubtitle]]? = nil,
        automaticCaptions: [String: [MediaSubtitle]]? = nil,
        chapters: [MediaChapter]? = nil,
        playlistTitle: String? = nil,
        playlistId: String? = nil,
        playlistCount: Int? = nil,
        entries: [PlaylistEntry]? = nil,
        isLive: Bool? = nil,
        height: Int? = nil,
        width: Int? = nil,
        resolution: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.uploader = uploader
        self.uploaderUrl = uploaderUrl
        self.channel = channel
        self.duration = duration
        self.thumbnail = thumbnail
        self.webpageUrl = webpageUrl
        self.viewCount = viewCount
        self.formats = formats
        self.subtitles = subtitles
        self.automaticCaptions = automaticCaptions
        self.chapters = chapters
        self.playlistTitle = playlistTitle
        self.playlistId = playlistId
        self.playlistCount = playlistCount
        self.entries = entries
        self.isLive = isLive
        self.height = height
        self.width = width
        self.resolution = resolution
    }

    var isPlaylist: Bool {
        if let entries = entries, !entries.isEmpty {
            return true
        }
        return playlistId != nil || (playlistCount ?? 0) > 1
    }

    var displayTitle: String {
        title ?? playlistTitle ?? "Untitled Media"
    }

    var displayUploader: String {
        uploader ?? channel ?? "Unknown Creator"
    }

    var formattedDuration: String {
        guard let duration = duration, duration > 0 else { return "" }
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var parsedFormats: [FormatOption] {
        guard let rawFormats = formats else { return [] }
        return rawFormats.compactMap { raw in
            guard let fid = raw.formatId else { return nil }
            return FormatOption(
                formatId: fid,
                ext: raw.ext ?? "mp4",
                resolution: raw.resolution,
                width: raw.width,
                height: raw.height,
                fps: raw.fps,
                vcodec: raw.vcodec,
                acodec: raw.acodec,
                filesize: raw.filesize,
                filesizeApprox: raw.filesizeApprox,
                tbr: raw.tbr,
                vbr: raw.vbr,
                abr: raw.abr,
                formatNote: raw.formatNote
            )
        }
    }

    /// Parses and deduplicates all video qualities actually available for this specific media.
    var detectedVideoQualities: [DetectedQuality] {
        guard let rawFormats = formats, !rawFormats.isEmpty else {
            if let h = height, h > 0 {
                let vq = VideoQuality.forHeight(h)
                return [DetectedQuality(
                    height: h,
                    width: width,
                    fps: 30,
                    hasHdr: false,
                    formatNote: nil,
                    filesize: nil,
                    filesizeApprox: nil,
                    videoQuality: vq
                )]
            }
            return []
        }

        // Filter video formats (must have video codec or positive height, and not be audio only)
        let videoStreams = rawFormats.filter { raw in
            let isAudioOnly = (raw.vcodec == "none" || raw.vcodec == nil) && (raw.acodec != nil && raw.acodec != "none")
            if isAudioOnly { return false }

            if let vc = raw.vcodec, vc != "none" { return true }
            if let h = raw.height, h > 0 { return true }
            if let res = raw.resolution, !res.lowercased().contains("audio") { return true }
            return false
        }

        struct StreamSpec {
            let height: Int
            let width: Int?
            let fps: Double
            let hasHdr: Bool
            let filesize: Int64?
            let filesizeApprox: Int64?
            let formatNote: String?
        }

        var specs: [StreamSpec] = []

        for raw in videoStreams {
            var h: Int? = raw.height
            if h == nil || h == 0 {
                if let res = raw.resolution {
                    let parts = res.components(separatedBy: CharacterSet(charactersIn: "xX"))
                    if parts.count == 2, let parsedH = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                        h = parsedH
                    }
                }
            }
            if h == nil || h == 0 {
                if let note = raw.formatNote {
                    let digits = note.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                    if let parsedH = Int(digits), parsedH >= 144 && parsedH <= 8640 {
                        h = parsedH
                    }
                }
            }
            if h == nil || h == 0 {
                if let w = raw.width, w > 0 {
                    h = Int(Double(w) * 9.0 / 16.0)
                }
            }

            guard let resolvedHeight = h, resolvedHeight > 0 else { continue }

            let fps = raw.fps ?? 30.0
            let hasHdr = (raw.dynamicRange?.uppercased().contains("HDR") == true) ||
                         (raw.formatNote?.uppercased().contains("HDR") == true)

            specs.append(StreamSpec(
                height: resolvedHeight,
                width: raw.width,
                fps: fps,
                hasHdr: hasHdr,
                filesize: raw.filesize,
                filesizeApprox: raw.filesizeApprox,
                formatNote: raw.formatNote
            ))
        }

        let standardTiers = [4320, 2160, 1440, 1080, 720, 480, 360, 240, 144]

        var grouped: [Int: [StreamSpec]] = [:]
        for spec in specs {
            let tier: Int
            if let matchedTier = standardTiers.first(where: { abs($0 - spec.height) <= 30 }) {
                tier = matchedTier
            } else {
                tier = spec.height
            }
            grouped[tier, default: []].append(spec)
        }

        var results: [DetectedQuality] = []
        for (heightTier, group) in grouped {
            let maxFps = group.map { $0.fps }.max() ?? 30.0
            let hasHdr = group.contains { $0.hasHdr }
            let maxFilesize = group.compactMap { $0.filesize }.max()
            let maxFilesizeApprox = group.compactMap { $0.filesizeApprox }.max()
            let firstWidth = group.compactMap { $0.width }.max()
            let note = group.compactMap { $0.formatNote }.first
            let vq = VideoQuality.forHeight(heightTier)

            results.append(DetectedQuality(
                height: heightTier,
                width: firstWidth,
                fps: maxFps,
                hasHdr: hasHdr,
                formatNote: note,
                filesize: maxFilesize,
                filesizeApprox: maxFilesizeApprox,
                videoQuality: vq
            ))
        }

        // The top-level height is yt-dlp's reported source maximum. Treat it as
        // authoritative so auxiliary or malformed format entries can never make
        // the UI offer an impossible higher resolution.
        if let sourceHeight = height, sourceHeight > 0 {
            results.removeAll { $0.height > sourceHeight + 30 }

            if results.isEmpty {
                results.append(DetectedQuality(
                    height: sourceHeight,
                    width: width,
                    fps: 30,
                    hasHdr: false,
                    formatNote: nil,
                    filesize: nil,
                    filesizeApprox: nil,
                    videoQuality: VideoQuality.forHeight(sourceHeight)
                ))
            }
        }

        results.sort { $0.height > $1.height }
        return results
    }

    var maxDetectedQuality: DetectedQuality? {
        detectedVideoQualities.first
    }

    var maxDetectedHeight: Int? {
        maxDetectedQuality?.height ?? height
    }

    var maxQualityBadgeText: String? {
        guard let maxQ = maxDetectedQuality else { return nil }
        return maxQ.label
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case uploader
        case uploaderUrl = "uploader_url"
        case channel
        case duration
        case thumbnail
        case webpageUrl = "webpage_url"
        case viewCount = "view_count"
        case formats
        case subtitles
        case automaticCaptions = "automatic_captions"
        case chapters
        case playlistTitle = "playlist_title"
        case playlistId = "playlist_id"
        case playlistCount = "playlist_count"
        case entries
        case isLive = "is_live"
        case height
        case width
        case resolution
    }
}

struct RawFormat: Codable {
    let formatId: String?
    let ext: String?
    let resolution: String?
    let width: Int?
    let height: Int?
    let fps: Double?
    let vcodec: String?
    let acodec: String?
    let filesize: Int64?
    let filesizeApprox: Int64?
    let tbr: Double?
    let vbr: Double?
    let abr: Double?
    let formatNote: String?
    let dynamicRange: String?

    enum CodingKeys: String, CodingKey {
        case formatId = "format_id"
        case ext
        case resolution
        case width
        case height
        case fps
        case vcodec
        case acodec
        case filesize
        case filesizeApprox = "filesize_approx"
        case tbr
        case vbr
        case abr
        case formatNote = "format_note"
        case dynamicRange = "dynamic_range"
    }
}
