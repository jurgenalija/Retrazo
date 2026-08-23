import Foundation

enum Constants {
    static let appName = "Retrazo"
    static let appVersion = "1.0.0"
    static let appAuthor = "Retrazo Team"
    static let githubRepo = "https://github.com/yt-dlp/yt-dlp"
    
    enum URLs {
        static let ytdlpReleasesAPI = "https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest"
        static let ytdlpMacOSBinary = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos"
        static let ytdlpUniversalBinary = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp"
    }
    
    enum Paths {
        static var applicationSupportDirectory: URL {
            let fileManager = FileManager.default
            let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            let appSupport = urls[0].appendingPathComponent(appName, isDirectory: true)
            try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
            return appSupport
        }
        
        static var binDirectory: URL {
            let bin = applicationSupportDirectory.appendingPathComponent("bin", isDirectory: true)
            try? FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
            return bin
        }
        
        static var managedYtDlpBinary: URL {
            binDirectory.appendingPathComponent("yt-dlp")
        }
        
        static var historyFile: URL {
            applicationSupportDirectory.appendingPathComponent("history.json")
        }
        
        static var defaultDownloadDirectory: URL {
            FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        }
    }
    
    enum SupportedPlatforms {
        static let domains: [String] = [
            "youtube.com", "youtu.be", "vimeo.com", "twitter.com", "x.com",
            "tiktok.com", "twitch.tv", "instagram.com", "facebook.com",
            "reddit.com", "bilibili.com", "soundcloud.com", "bandcamp.com",
            "dailymotion.com", "vk.com", "streamable.com", "odysee.com",
            "rumble.com", "loom.com"
        ]
        
        static func isSupported(url: String) -> Bool {
            guard let host = URL(string: url)?.host?.lowercased() else { return false }
            return domains.contains { host.contains($0) }
        }
    }
}
