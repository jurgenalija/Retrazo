import Foundation

struct DownloadProgress {
    var progress: Double // 0.0 ... 1.0
    var speed: String
    var eta: String
    var downloadedBytes: Int64
    var totalBytes: Int64
    var totalBytesEstimated: Bool
    var status: DownloadStatus
    var outputPath: String?
}

class ProcessTask {
    private let process: Process
    private var isCancelled = false
    
    init(process: Process) {
        self.process = process
    }
    
    func cancel() {
        isCancelled = true
        if process.isRunning {
            process.terminate()
        }
    }
    
    var isRunning: Bool {
        process.isRunning
    }
}

class YtDlpProcessManager {
    static let shared = YtDlpProcessManager()
    
    // MARK: - Metadata Extraction
    
    func fetchMediaInfo(url: String, customArgs: [String] = []) async throws -> MediaInfo {
        let customYt = AppSettings.shared.customYtDlpPath
        let customCookies = AppSettings.shared.customCookiesPath
        let browserCookies = AppSettings.shared.browserCookies
        let customFfmpeg = AppSettings.shared.customFfmpegPath
        
        guard let ytDlpPath = BinaryManager.findYtDlpPath(customPath: customYt) else {
            throw NSError(
                domain: "YtDlpProcessManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "yt-dlp binary not found. Please install or download yt-dlp in Settings."]
            )
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                
                process.executableURL = URL(fileURLWithPath: ytDlpPath)
                
                var args = [
                    "-J",
                    "--flat-playlist",
                    "--no-warnings"
                ]
                
                if browserCookies != "none" && !browserCookies.isEmpty {
                    args.append(contentsOf: ["--cookies-from-browser", browserCookies])
                } else if !customCookies.isEmpty {
                    args.append(contentsOf: ["--cookies", customCookies])
                }
                
                args.append(contentsOf: customArgs)
                args.append(url)
                
                process.arguments = args
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe
                
                var environment = ProcessInfo.processInfo.environment
                if let ffmpeg = BinaryManager.findFfmpegPath(customPath: customFfmpeg) {
                    let ffmpegDir = (ffmpeg as NSString).deletingLastPathComponent
                    let currentPath = environment["PATH"] ?? ""
                    environment["PATH"] = "\(ffmpegDir):\(currentPath)"
                }
                process.environment = environment
                
                do {
                    try process.run()
                    
                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    process.waitUntilExit()
                    
                    if process.terminationStatus == 0 {
                        do {
                            let mediaInfo = try JSONDecoder().decode(MediaInfo.self, from: stdoutData)
                            continuation.resume(returning: mediaInfo)
                        } catch {
                            if let dict = try? JSONSerialization.jsonObject(with: stdoutData) as? [String: Any] {
                                let id = dict["id"] as? String ?? UUID().uuidString
                                let title = dict["title"] as? String ?? "Media Item"
                                let duration = dict["duration"] as? Double
                                let uploader = dict["uploader"] as? String
                                let thumbnail = dict["thumbnail"] as? String
                                
                                let fallbackInfo = MediaInfo(
                                    id: id,
                                    title: title,
                                    description: dict["description"] as? String,
                                    uploader: uploader,
                                    uploaderUrl: nil,
                                    channel: dict["channel"] as? String,
                                    duration: duration,
                                    thumbnail: thumbnail,
                                    webpageUrl: url,
                                    viewCount: dict["view_count"] as? Int,
                                    formats: nil,
                                    subtitles: nil,
                                    automaticCaptions: nil,
                                    chapters: nil,
                                    playlistTitle: dict["playlist_title"] as? String,
                                    playlistId: dict["playlist_id"] as? String,
                                    playlistCount: dict["playlist_count"] as? Int,
                                    entries: nil,
                                    isLive: dict["is_live"] as? Bool
                                )
                                continuation.resume(returning: fallbackInfo)
                            } else {
                                continuation.resume(throwing: error)
                            }
                        }
                    } else {
                        let errOutput = String(data: stderrData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: NSError(
                            domain: "YtDlpProcessManager",
                            code: Int(process.terminationStatus),
                            userInfo: [NSLocalizedDescriptionKey: errOutput.trimmingCharacters(in: .whitespacesAndNewlines)]
                        ))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Download Execution
    
    func startDownload(
        item: DownloadItem,
        settings: AppSettings,
        onProgress: @escaping (DownloadProgress) -> Void,
        onLog: @escaping (String) -> Void,
        onCompletion: @escaping (Result<String?, Error>) -> Void
    ) -> ProcessTask? {
        guard let ytDlpPath = BinaryManager.findYtDlpPath(customPath: settings.customYtDlpPath) else {
            onCompletion(.failure(NSError(
                domain: "YtDlpProcessManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "yt-dlp binary not found."]
            )))
            return nil
        }
        
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        
        let args = buildDownloadArguments(item: item, settings: settings)
        process.arguments = args
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        var environment = ProcessInfo.processInfo.environment
        if let ffmpeg = BinaryManager.findFfmpegPath(customPath: settings.customFfmpegPath) {
            let ffmpegDir = (ffmpeg as NSString).deletingLastPathComponent
            let currentPath = environment["PATH"] ?? ""
            environment["PATH"] = "\(ffmpegDir):\(currentPath)"
        }
        process.environment = environment
        
        var detectedOutputPath: String? = nil
        let regexProgress = try? NSRegularExpression(pattern: #"\b(\d+(?:\.\d+)?)%\s+of\s+(~?\s*\d+(?:\.\d+)?[KMGTP]?i?B)(?:\s+at\s+(\d+(?:\.\d+)?[KMGTP]?i?B/s))?(?:\s+ETA\s+(\d+:\d+(?::\d+)?|\d+s))?"#, options: .caseInsensitive)
        
        let handleLine: (String) -> Void = { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            
            onLog(trimmed)
            
            if trimmed.contains("[download] Destination: ") {
                let path = trimmed.replacingOccurrences(of: "[download] Destination: ", with: "").trimmingCharacters(in: .whitespaces)
                detectedOutputPath = path
                onProgress(DownloadProgress(progress: 0.0, speed: "", eta: "", downloadedBytes: 0, totalBytes: 0, totalBytesEstimated: false, status: .downloading, outputPath: path))
            } else if trimmed.contains("[Merger] Merging formats into \"") {
                if let start = trimmed.range(of: "\"", options: .backwards),
                   let firstQuote = trimmed.range(of: "\"") {
                    let path = String(trimmed[firstQuote.upperBound..<start.lowerBound])
                    detectedOutputPath = path
                }
                onProgress(DownloadProgress(progress: 0.98, speed: "", eta: "", downloadedBytes: 0, totalBytes: 0, totalBytesEstimated: false, status: .processing, outputPath: detectedOutputPath))
            } else if trimmed.contains("[ExtractAudio] Destination: ") {
                let path = trimmed.replacingOccurrences(of: "[ExtractAudio] Destination: ", with: "").trimmingCharacters(in: .whitespaces)
                detectedOutputPath = path
            }
            
            if let regex = regexProgress {
                let nsString = trimmed as NSString
                let results = regex.matches(in: trimmed, range: NSRange(location: 0, length: nsString.length))
                if let match = results.first {
                    var percent: Double = 0
                    var speedStr = ""
                    var etaStr = ""
                    var totalSizeStr = ""
                    
                    if match.numberOfRanges > 1 && match.range(at: 1).location != NSNotFound {
                        let pStr = nsString.substring(with: match.range(at: 1))
                        percent = (Double(pStr) ?? 0.0) / 100.0
                    }
                    if match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound {
                        totalSizeStr = nsString.substring(with: match.range(at: 2))
                    }
                    if match.numberOfRanges > 3 && match.range(at: 3).location != NSNotFound {
                        speedStr = nsString.substring(with: match.range(at: 3))
                    }
                    if match.numberOfRanges > 4 && match.range(at: 4).location != NSNotFound {
                        etaStr = nsString.substring(with: match.range(at: 4))
                    }
                    
                    let isEstimated = totalSizeStr.contains("~")
                    let totalBytes = self.parseBytes(from: totalSizeStr)
                    let downloadedBytes = Int64(Double(totalBytes) * percent)
                    
                    onProgress(DownloadProgress(
                        progress: percent,
                        speed: speedStr,
                        eta: etaStr,
                        downloadedBytes: downloadedBytes,
                        totalBytes: totalBytes,
                        totalBytesEstimated: isEstimated,
                        status: percent >= 1.0 ? .processing : .downloading,
                        outputPath: detectedOutputPath
                    ))
                }
            }
        }
        
        let setupPipeReading = { (pipe: Pipe) in
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                if let str = String(data: data, encoding: .utf8) {
                    let lines = str.components(separatedBy: CharacterSet(charactersIn: "\r\n"))
                    for l in lines {
                        if !l.isEmpty {
                            handleLine(l)
                        }
                    }
                }
            }
        }
        
        setupPipeReading(stdoutPipe)
        setupPipeReading(stderrPipe)
        
        do {
            try process.run()
            let task = ProcessTask(process: process)
            
            DispatchQueue.global(qos: .userInitiated).async {
                process.waitUntilExit()
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                
                if process.terminationStatus == 0 {
                    onCompletion(.success(detectedOutputPath))
                } else {
                    let err = NSError(
                        domain: "YtDlpProcessManager",
                        code: Int(process.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: "Download failed with exit code \(process.terminationStatus)"]
                    )
                    onCompletion(.failure(err))
                }
            }
            
            return task
        } catch {
            onCompletion(.failure(error))
            return nil
        }
    }
    
    // MARK: - Argument Builder
    
    private func buildDownloadArguments(item: DownloadItem, settings: AppSettings) -> [String] {
        var args: [String] = []
        
        args.append(contentsOf: [
            "--newline",
            "--no-colors"
        ])
        
        let outputTemplate = "\(settings.downloadDirectory)/\(settings.filenameTemplate)"
        args.append(contentsOf: ["-o", outputTemplate])
        
        let preset = item.preset
        if preset.extractAudio {
            args.append(contentsOf: [
                "-x",
                "--audio-format", preset.audioFormat.rawValue,
                "--audio-quality", preset.audioQuality.ytdlpQualityArg
            ])
        } else {
            let formatStr = preset.buildFormatString()
            args.append(contentsOf: ["-f", formatStr])
            args.append(contentsOf: ["--merge-output-format", preset.videoContainer.rawValue])
        }
        
        if let ffmpeg = BinaryManager.findFfmpegPath(customPath: settings.customFfmpegPath) {
            let ffmpegDir = (ffmpeg as NSString).deletingLastPathComponent
            args.append(contentsOf: ["--ffmpeg-location", ffmpegDir])
        }
        
        if settings.embedThumbnail {
            args.append("--embed-thumbnail")
        }
        if settings.embedMetadata {
            args.append("--embed-metadata")
        }
        if settings.embedChapters {
            args.append("--embed-chapters")
        }
        
        if settings.embedSubtitles {
            args.append(contentsOf: [
                "--embed-subs",
                "--sub-langs", settings.subtitleLanguage.isEmpty ? "all" : settings.subtitleLanguage
            ])
        }
        
        if settings.sponsorBlockEnabled && !settings.sponsorBlockCategories.isEmpty {
            args.append(contentsOf: [
                "--sponsorblock-remove", settings.sponsorBlockCategories
            ])
        }
        
        if settings.browserCookies != "none" && !settings.browserCookies.isEmpty {
            args.append(contentsOf: ["--cookies-from-browser", settings.browserCookies])
        } else if !settings.customCookiesPath.isEmpty {
            args.append(contentsOf: ["--cookies", settings.customCookiesPath])
        }
        
        if settings.rateLimitKbps > 0 {
            args.append(contentsOf: ["--limit-rate", "\(settings.rateLimitKbps)K"])
        }
        
        if !settings.customArguments.trimmingCharacters(in: .whitespaces).isEmpty {
            let extra = settings.customArguments.split(separator: " ").map(String.init)
            args.append(contentsOf: extra)
        }
        
        args.append(contentsOf: item.customArgs)
        args.append(item.url)
        
        return args
    }
    
    private func parseBytes(from string: String) -> Int64 {
        let cleaned = string.replacingOccurrences(of: "~", with: "")
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
        
        let scanner = Scanner(string: cleaned)
        if let value = scanner.scanDouble() {
            let rest = cleaned.replacingOccurrences(of: String(value), with: "")
            if rest.contains("G") {
                return Int64(value * 1024 * 1024 * 1024)
            } else if rest.contains("M") {
                return Int64(value * 1024 * 1024)
            } else if rest.contains("K") {
                return Int64(value * 1024)
            } else {
                return Int64(value)
            }
        }
        return 0
    }
}
