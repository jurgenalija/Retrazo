import Foundation

enum DownloadType: String, Codable, CaseIterable, Identifiable {
    case video = "Video"
    case audio = "Audio"
    case custom = "Custom"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .video: return "video.fill"
        case .audio: return "music.note"
        case .custom: return "slider.horizontal.3"
        }
    }
}

enum VideoContainer: String, Codable, CaseIterable, Identifiable {
    case mp4 = "mp4"
    case mkv = "mkv"
    case webm = "webm"
    case mov = "mov"

    var id: String { rawValue }
    var displayName: String { rawValue.uppercased() }
}

enum AudioFormat: String, Codable, CaseIterable, Identifiable {
    case mp3 = "mp3"
    case m4a = "m4a"
    case flac = "flac"
    case wav = "wav"
    case opus = "opus"
    case aac = "aac"

    var id: String { rawValue }
    var displayName: String { rawValue.uppercased() }
}

enum VideoQuality: String, Codable, CaseIterable, Identifiable {
    case best = "best"
    case uhd8k = "4320p (8K)"
    case uhd4k = "2160p (4K)"
    case qhd1440 = "1440p (2K)"
    case fhd1080 = "1080p (Full HD)"
    case hd720 = "720p (HD)"
    case sd480 = "480p (SD)"
    case sd360 = "360p"
    case sd240 = "240p"
    case sd144 = "144p"

    var id: String { rawValue }

    var maxHeight: Int? {
        switch self {
        case .best: return nil
        case .uhd8k: return 4320
        case .uhd4k: return 2160
        case .qhd1440: return 1440
        case .fhd1080: return 1080
        case .hd720: return 720
        case .sd480: return 480
        case .sd360: return 360
        case .sd240: return 240
        case .sd144: return 144
        }
    }

    var shortLabel: String {
        switch self {
        case .best: return "Maximum"
        case .uhd8k: return "8K"
        case .uhd4k: return "4K"
        case .qhd1440: return "1440p"
        case .fhd1080: return "1080p"
        case .hd720: return "720p"
        case .sd480: return "480p"
        case .sd360: return "360p"
        case .sd240: return "240p"
        case .sd144: return "144p"
        }
    }

    static func forHeight(_ height: Int) -> VideoQuality {
        switch height {
        case 4320...: return .uhd8k
        case 2160...4319: return .uhd4k
        case 1440...2159: return .qhd1440
        case 1080...1439: return .fhd1080
        case 720...1079: return .hd720
        case 480...719: return .sd480
        case 360...479: return .sd360
        case 240...359: return .sd240
        default: return .sd144
        }
    }
}

enum AudioQuality: String, Codable, CaseIterable, Identifiable {
    case best = "best"
    case kbps320 = "320 kbps"
    case kbps256 = "256 kbps"
    case kbps192 = "192 kbps"
    case kbps128 = "128 kbps"

    var id: String { rawValue }

    var ytdlpQualityArg: String {
        switch self {
        case .best: return "0"
        case .kbps320: return "320K"
        case .kbps256: return "256K"
        case .kbps192: return "192K"
        case .kbps128: return "128K"
        }
    }
}

struct DownloadPreset: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var type: DownloadType
    var videoQuality: VideoQuality
    var customMaxHeight: Int?
    var videoContainer: VideoContainer
    var audioFormat: AudioFormat
    var audioQuality: AudioQuality
    var extractAudio: Bool

    init(
        id: String,
        name: String,
        type: DownloadType,
        videoQuality: VideoQuality,
        customMaxHeight: Int? = nil,
        videoContainer: VideoContainer = .mp4,
        audioFormat: AudioFormat = .m4a,
        audioQuality: AudioQuality = .best,
        extractAudio: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.videoQuality = videoQuality
        self.customMaxHeight = customMaxHeight
        self.videoContainer = videoContainer
        self.audioFormat = audioFormat
        self.audioQuality = audioQuality
        self.extractAudio = extractAudio
    }

    static let bestVideo = DownloadPreset(
        id: "best-video-mp4",
        name: "Maximum Available (MP4)",
        type: .video,
        videoQuality: .best,
        videoContainer: .mp4,
        audioFormat: .m4a,
        audioQuality: .best,
        extractAudio: false
    )

    static let bestVideoMkv = DownloadPreset(
        id: "best-video-mkv",
        name: "Maximum Available (MKV)",
        type: .video,
        videoQuality: .best,
        videoContainer: .mkv,
        audioFormat: .m4a,
        audioQuality: .best,
        extractAudio: false
    )

    static let video1080p = DownloadPreset(
        id: "video-1080p",
        name: "1080p Full HD (MP4)",
        type: .video,
        videoQuality: .fhd1080,
        customMaxHeight: 1080,
        videoContainer: .mp4,
        audioFormat: .m4a,
        audioQuality: .best,
        extractAudio: false
    )

    static let video720p = DownloadPreset(
        id: "video-720p",
        name: "720p HD (MP4)",
        type: .video,
        videoQuality: .hd720,
        customMaxHeight: 720,
        videoContainer: .mp4,
        audioFormat: .m4a,
        audioQuality: .best,
        extractAudio: false
    )

    static let video4k = DownloadPreset(
        id: "video-4k",
        name: "4K Ultra HD (MP4)",
        type: .video,
        videoQuality: .uhd4k,
        customMaxHeight: 2160,
        videoContainer: .mp4,
        audioFormat: .m4a,
        audioQuality: .best,
        extractAudio: false
    )

    static let audioMp3Best = DownloadPreset(
        id: "audio-mp3-320",
        name: "MP3 Audio (320 kbps)",
        type: .audio,
        videoQuality: .best,
        videoContainer: .mp4,
        audioFormat: .mp3,
        audioQuality: .kbps320,
        extractAudio: true
    )

    static let audioM4aBest = DownloadPreset(
        id: "audio-m4a-best",
        name: "M4A Audio (Source Quality)",
        type: .audio,
        videoQuality: .best,
        videoContainer: .mp4,
        audioFormat: .m4a,
        audioQuality: .best,
        extractAudio: true
    )

    static let audioFlacLossless = DownloadPreset(
        id: "audio-flac-lossless",
        name: "FLAC Audio",
        type: .audio,
        videoQuality: .best,
        videoContainer: .mp4,
        audioFormat: .flac,
        audioQuality: .best,
        extractAudio: true
    )

    static let defaultPresets: [DownloadPreset] = [
        .bestVideo,
        .video1080p,
        .video720p,
        .video4k,
        .bestVideoMkv,
        .audioMp3Best,
        .audioM4aBest,
        .audioFlacLossless
    ]

    static func preset(for quality: DetectedQuality, container: VideoContainer = .mp4) -> DownloadPreset {
        return DownloadPreset(
            id: "video-\(quality.height)p-\(container.rawValue)",
            name: "\(quality.label) (\(container.displayName))",
            type: .video,
            videoQuality: quality.videoQuality,
            customMaxHeight: quality.height,
            videoContainer: container,
            audioFormat: .m4a,
            audioQuality: .best,
            extractAudio: false
        )
    }

    static func bestVideo(container: VideoContainer = .mp4, maxQuality: DetectedQuality? = nil) -> DownloadPreset {
        let name: String
        if let maxQ = maxQuality {
            name = "Source Maximum (\(maxQ.resolutionBadge) • \(container.displayName))"
        } else {
            name = "Source Maximum (\(container.displayName))"
        }
        return DownloadPreset(
            id: "best-video-\(container.rawValue)",
            name: name,
            type: .video,
            videoQuality: .best,
            customMaxHeight: nil,
            videoContainer: container,
            audioFormat: .m4a,
            audioQuality: .best,
            extractAudio: false
        )
    }

    func buildFormatString() -> String {
        if extractAudio {
            return "bestaudio/best"
        }

        let heightLimit = customMaxHeight ?? videoQuality.maxHeight
        if let maxH = heightLimit {
            return "bestvideo*[height<=\(maxH)]+bestaudio/best[height<=\(maxH)]"
        } else {
            return "bestvideo+bestaudio/best"
        }
    }
}
