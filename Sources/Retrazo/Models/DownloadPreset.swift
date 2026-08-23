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
    var videoContainer: VideoContainer
    var audioFormat: AudioFormat
    var audioQuality: AudioQuality
    var extractAudio: Bool
    
    static let bestVideo = DownloadPreset(
        id: "best-video-mp4",
        name: "Best Quality (MP4)",
        type: .video,
        videoQuality: .best,
        videoContainer: .mp4,
        audioFormat: .m4a,
        audioQuality: .best,
        extractAudio: false
    )
    
    static let bestVideoMkv = DownloadPreset(
        id: "best-video-mkv",
        name: "Best Quality (MKV)",
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
        videoContainer: .mp4,
        audioFormat: .m4a,
        audioQuality: .best,
        extractAudio: false
    )
    
    static let video4k = DownloadPreset(
        id: "video-4k",
        name: "4K Ultra HD (MP4/MKV)",
        type: .video,
        videoQuality: .uhd4k,
        videoContainer: .mp4,
        audioFormat: .m4a,
        audioQuality: .best,
        extractAudio: false
    )
    
    static let audioMp3Best = DownloadPreset(
        id: "audio-mp3-320",
        name: "Audio MP3 (Best 320k)",
        type: .audio,
        videoQuality: .best,
        videoContainer: .mp4,
        audioFormat: .mp3,
        audioQuality: .kbps320,
        extractAudio: true
    )
    
    static let audioM4aBest = DownloadPreset(
        id: "audio-m4a-best",
        name: "Audio M4A / AAC",
        type: .audio,
        videoQuality: .best,
        videoContainer: .mp4,
        audioFormat: .m4a,
        audioQuality: .best,
        extractAudio: true
    )
    
    static let audioFlacLossless = DownloadPreset(
        id: "audio-flac-lossless",
        name: "Audio FLAC (Lossless)",
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
        .video4k,
        .bestVideoMkv,
        .audioMp3Best,
        .audioM4aBest,
        .audioFlacLossless
    ]
    
    func buildFormatString() -> String {
        if extractAudio {
            return "bestaudio/best"
        }
        
        if let maxH = videoQuality.maxHeight {
            return "bestvideo[height<=\(maxH)]+bestaudio/best[height<=\(maxH)]/best"
        } else {
            return "bestvideo+bestaudio/best"
        }
    }
}
