import Foundation
import Combine

struct YtDlpReleaseInfo: Codable {
    let tagName: String
    let name: String?
    let publishedAt: String?
    let body: String?
    let htmlUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case publishedAt = "published_at"
        case body
        case htmlUrl = "html_url"
    }
    
    var formattedDate: String {
        guard let publishedAt = publishedAt else { return "" }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: publishedAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }
        return publishedAt
    }
}

enum BinaryStatus: Equatable {
    case checking
    case installed(version: String, path: String)
    case notInstalled
    case error(String)
}

@MainActor
class BinaryManager: ObservableObject {
    static let shared = BinaryManager()
    
    @Published var ytDlpStatus: BinaryStatus = .checking
    @Published var currentVersion: String? = nil
    @Published var latestVersion: String? = nil
    @Published var releaseInfo: YtDlpReleaseInfo? = nil
    @Published var isUpdateAvailable: Bool = false
    
    @Published var ffmpegPath: String? = nil
    @Published var isFfmpegInstalled: Bool = false
    
    @Published var isUpdating: Bool = false
    @Published var updateProgress: Double = 0.0
    @Published var updateStatusMessage: String = ""
    @Published var lastCheckDate: Date? = nil
    
    private let settings = AppSettings.shared
    
    init() {
        Task {
            await refreshAll()
            if settings.autoCheckYtDlpUpdates {
                await checkForUpdates(silent: true)
            }
        }
    }
    
    func refreshAll() async {
        await checkFfmpeg()
        await checkYtDlp()
    }
    
    // MARK: - Binary Path Discovery
    
    nonisolated static func findYtDlpPath(customPath: String = "") -> String? {
        let trimmedCustom = customPath.trimmingCharacters(in: .whitespaces)
        if !trimmedCustom.isEmpty && FileManager.default.isExecutableFile(atPath: trimmedCustom) {
            return trimmedCustom
        }
        
        let managedPath = Constants.Paths.managedYtDlpBinary.path
        if FileManager.default.isExecutableFile(atPath: managedPath) {
            return managedPath
        }
        
        let commonPaths = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "/usr/bin/yt-dlp",
            "~/.local/bin/yt-dlp"
        ]
        
        for p in commonPaths {
            let expanded = NSString(string: p).expandingTildeInPath
            if FileManager.default.isExecutableFile(atPath: expanded) {
                return expanded
            }
        }
        
        return findBinaryInSystemPath(name: "yt-dlp")
    }
    
    nonisolated static func findFfmpegPath(customPath: String = "") -> String? {
        let trimmedCustom = customPath.trimmingCharacters(in: .whitespaces)
        if !trimmedCustom.isEmpty && FileManager.default.isExecutableFile(atPath: trimmedCustom) {
            return trimmedCustom
        }
        
        let managedFfmpeg = Constants.Paths.binDirectory.appendingPathComponent("ffmpeg").path
        if FileManager.default.isExecutableFile(atPath: managedFfmpeg) {
            return managedFfmpeg
        }
        
        let commonPaths = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]
        
        for p in commonPaths {
            let expanded = NSString(string: p).expandingTildeInPath
            if FileManager.default.isExecutableFile(atPath: expanded) {
                return expanded
            }
        }
        
        return findBinaryInSystemPath(name: "ffmpeg")
    }
    
    nonisolated private static func findBinaryInSystemPath(name: String) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        var environment = ProcessInfo.processInfo.environment
        let extraPaths = "/opt/homebrew/bin:/usr/local/bin:~/.local/bin"
        if let currentPath = environment["PATH"] {
            environment["PATH"] = "\(extraPaths):\(currentPath)"
        } else {
            environment["PATH"] = extraPaths
        }
        process.environment = environment
        
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !output.isEmpty, FileManager.default.isExecutableFile(atPath: output) {
                    return output
                }
            }
        } catch {
            return nil
        }
        return nil
    }
    
    func resolvedYtDlpPath() -> String? {
        Self.findYtDlpPath(customPath: settings.customYtDlpPath)
    }
    
    func resolvedFfmpegPath() -> String? {
        Self.findFfmpegPath(customPath: settings.customFfmpegPath)
    }
    
    // MARK: - Validation & Version Checks
    
    func checkYtDlp() async {
        guard let path = resolvedYtDlpPath() else {
            self.ytDlpStatus = .notInstalled
            self.currentVersion = nil
            return
        }
        
        do {
            let version = try await fetchLocalVersion(executablePath: path)
            self.currentVersion = version
            self.ytDlpStatus = .installed(version: version, path: path)
            self.compareVersions()
        } catch {
            self.ytDlpStatus = .error(error.localizedDescription)
            self.currentVersion = nil
        }
    }
    
    func checkFfmpeg() async {
        if let path = resolvedFfmpegPath() {
            self.ffmpegPath = path
            self.isFfmpegInstalled = true
        } else {
            self.ffmpegPath = nil
            self.isFfmpegInstalled = false
        }
    }
    
    private func fetchLocalVersion(executablePath: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                process.executableURL = URL(fileURLWithPath: executablePath)
                process.arguments = ["--version"]
                process.standardOutput = pipe
                process.standardError = Pipe()
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let version = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !version.isEmpty {
                        continuation.resume(returning: version)
                    } else {
                        continuation.resume(throwing: NSError(domain: "BinaryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read version from yt-dlp"]))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Check GitHub Releases
    
    func checkForUpdates(silent: Bool = false) async {
        guard let url = URL(string: Constants.URLs.ytdlpReleasesAPI) else { return }
        
        if !silent {
            isUpdating = true
            updateStatusMessage = "Checking for latest yt-dlp release..."
        }
        
        do {
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            request.setValue("Retrazo-Mac-App", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10.0
            
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                let release = try JSONDecoder().decode(YtDlpReleaseInfo.self, from: data)
                self.releaseInfo = release
                self.latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
                self.lastCheckDate = Date()
                self.compareVersions()
            }
        } catch {
            print("Failed to check yt-dlp release: \(error)")
        }
        
        if !silent {
            isUpdating = false
            updateStatusMessage = ""
        }
    }
    
    private func compareVersions() {
        guard let cur = currentVersion, let latest = latestVersion else {
            isUpdateAvailable = false
            return
        }
        
        let cleanedCur = cur.replacingOccurrences(of: "v", with: "").trimmingCharacters(in: .whitespaces)
        let cleanedLat = latest.replacingOccurrences(of: "v", with: "").trimmingCharacters(in: .whitespaces)
        
        if cleanedCur != cleanedLat {
            isUpdateAvailable = (cleanedCur.compare(cleanedLat, options: .numeric) == .orderedAscending)
        } else {
            isUpdateAvailable = false
        }
    }
    
    // MARK: - Download / Update yt-dlp Binary
    
    func downloadOrUpdateYtDlp() async {
        isUpdating = true
        updateProgress = 0.0
        updateStatusMessage = "Downloading latest yt-dlp for macOS..."
        
        let targetURL = Constants.Paths.managedYtDlpBinary
        let downloadURL = URL(string: Constants.URLs.ytdlpMacOSBinary) ?? URL(string: Constants.URLs.ytdlpUniversalBinary)!
        
        do {
            var request = URLRequest(url: downloadURL)
            request.setValue("Retrazo-Mac-App", forHTTPHeaderField: "User-Agent")
            
            let (tempURL, response) = try await URLSession.shared.download(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "BinaryManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Download failed with invalid server response"])
            }
            
            updateStatusMessage = "Installing binary..."
            updateProgress = 0.85
            
            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.removeItem(at: targetURL)
            }
            
            try FileManager.default.moveItem(at: tempURL, to: targetURL)
            
            let attributes: [FileAttributeKey: Any] = [.posixPermissions: 0o755]
            try FileManager.default.setAttributes(attributes, ofItemAtPath: targetURL.path)
            
            updateProgress = 1.0
            updateStatusMessage = "yt-dlp updated successfully!"
            
            await checkYtDlp()
            
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            isUpdating = false
            updateStatusMessage = ""
        } catch {
            print("Failed to download yt-dlp: \(error)")
            updateStatusMessage = "Update failed: \(error.localizedDescription)"
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            isUpdating = false
            updateStatusMessage = ""
        }
    }
}
