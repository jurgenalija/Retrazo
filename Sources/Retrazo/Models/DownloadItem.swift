import Foundation

struct DownloadOptionOverrides: Codable, Equatable {
    var embedThumbnail: Bool
    var embedMetadata: Bool
    var embedChapters: Bool
    var embedSubtitles: Bool
    var subtitleLanguage: String
    var sponsorBlockEnabled: Bool
    /// Optional so download history saved by older versions remains decodable.
    var splitChapters: Bool?
}

enum DownloadStatus: String, Codable, CaseIterable {
    case queued = "Queued"
    case analyzing = "Analyzing"
    case downloading = "Downloading"
    case processing = "Processing"
    case paused = "Paused"
    case finished = "Finished"
    case failed = "Failed"
    case cancelled = "Cancelled"
    
    var isTerminal: Bool {
        self == .finished || self == .failed || self == .cancelled
    }
    
    var isActive: Bool {
        self == .analyzing || self == .downloading || self == .processing
    }
}

struct DownloadItem: Codable, Identifiable, Equatable {
    var id: UUID
    var url: String
    var title: String
    var thumbnailUrl: String?
    var duration: Double?
    var uploader: String?
    var status: DownloadStatus
    
    var progress: Double // 0.0 ... 1.0
    var speed: String
    var eta: String
    var downloadedBytes: Int64
    var totalBytes: Int64
    var totalBytesEstimated: Bool
    
    var formatDescription: String
    var outputPath: String?
    var errorMessage: String?
    var logs: [String]
    
    var createdAt: Date
    var completedAt: Date?
    
    var customArgs: [String]
    var preset: DownloadPreset
    var optionOverrides: DownloadOptionOverrides?
    var isPlaylist: Bool
    var playlistCount: Int?
    var playlistIndex: Int?
    
    init(
        id: UUID = UUID(),
        url: String,
        title: String = "Preparing download...",
        thumbnailUrl: String? = nil,
        duration: Double? = nil,
        uploader: String? = nil,
        status: DownloadStatus = .queued,
        progress: Double = 0.0,
        speed: String = "",
        eta: String = "",
        downloadedBytes: Int64 = 0,
        totalBytes: Int64 = 0,
        totalBytesEstimated: Bool = false,
        formatDescription: String = "Source Maximum",
        outputPath: String? = nil,
        errorMessage: String? = nil,
        logs: [String] = [],
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        customArgs: [String] = [],
        preset: DownloadPreset = .bestVideo,
        optionOverrides: DownloadOptionOverrides? = nil,
        isPlaylist: Bool = false,
        playlistCount: Int? = nil,
        playlistIndex: Int? = nil
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.thumbnailUrl = thumbnailUrl
        self.duration = duration
        self.uploader = uploader
        self.status = status
        self.progress = progress
        self.speed = speed
        self.eta = eta
        self.downloadedBytes = downloadedBytes
        self.totalBytes = totalBytes
        self.totalBytesEstimated = totalBytesEstimated
        self.formatDescription = formatDescription
        self.outputPath = outputPath
        self.errorMessage = errorMessage
        self.logs = logs
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.customArgs = customArgs
        self.preset = preset
        self.optionOverrides = optionOverrides
        self.isPlaylist = isPlaylist
        self.playlistCount = playlistCount
        self.playlistIndex = playlistIndex
    }
    
    var formattedDuration: String {
        guard let duration = duration, duration > 0 else { return "" }
        let totalSec = Int(duration)
        let hours = totalSec / 3600
        let minutes = (totalSec % 3600) / 60
        let seconds = totalSec % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var formattedSizeInfo: String {
        if totalBytes > 0 {
            let downloaded = ByteCountFormatter.string(fromByteCount: downloadedBytes, countStyle: .file)
            let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            let approx = totalBytesEstimated ? "~" : ""
            return "\(downloaded) / \(approx)\(total)"
        } else if downloadedBytes > 0 {
            return ByteCountFormatter.string(fromByteCount: downloadedBytes, countStyle: .file)
        }
        return ""
    }
    
    var formattedSpeedAndEta: String {
        var parts: [String] = []
        if !speed.isEmpty {
            parts.append(speed)
        }
        if !eta.isEmpty {
            parts.append("ETA \(eta)")
        }
        return parts.joined(separator: " • ")
    }
    
    static func == (lhs: DownloadItem, rhs: DownloadItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.status == rhs.status &&
        lhs.progress == rhs.progress &&
        lhs.speed == rhs.speed &&
        lhs.eta == rhs.eta &&
        lhs.downloadedBytes == rhs.downloadedBytes &&
        lhs.totalBytes == rhs.totalBytes &&
        lhs.totalBytesEstimated == rhs.totalBytesEstimated &&
        lhs.title == rhs.title &&
        lhs.uploader == rhs.uploader &&
        lhs.thumbnailUrl == rhs.thumbnailUrl &&
        lhs.outputPath == rhs.outputPath &&
        lhs.errorMessage == rhs.errorMessage &&
        lhs.logs.count == rhs.logs.count
    }
}
