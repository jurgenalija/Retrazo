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
    }
}
