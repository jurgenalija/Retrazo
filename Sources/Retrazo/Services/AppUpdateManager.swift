import AppKit
import Combine
import CryptoKit
import Foundation

struct AppReleaseAsset: Decodable, Identifiable {
    let id: Int
    let name: String
    let browserDownloadURL: URL
    let size: Int?
    let digest: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case browserDownloadURL = "browser_download_url"
        case size
        case digest
    }
}

struct AppReleaseInfo: Decodable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL?
    let publishedAt: String?
    let assets: [AppReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case assets
    }

    var version: String {
        tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    var formattedDate: String {
        guard let publishedAt else { return "" }
        let input = ISO8601DateFormatter()
        guard let date = input.date(from: publishedAt) else { return publishedAt }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

@MainActor
final class AppUpdateManager: ObservableObject {
    static let shared = AppUpdateManager()

    @Published private(set) var latestRelease: AppReleaseInfo?
    @Published private(set) var latestVersion: String?
    @Published private(set) var isUpdateAvailable = false
    @Published private(set) var isBusy = false
    @Published private(set) var statusMessage = ""
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastCheckDate: Date?

    var currentVersion: String { Constants.appVersion }

    private init() {
        if AppSettings.shared.autoCheckAppUpdates {
            Task {
                await checkForUpdates(silent: true)
            }
        }
    }

    func checkForUpdates(silent: Bool = false) async {
        guard let url = URL(string: Constants.URLs.appReleasesAPI) else { return }

        isBusy = true
        errorMessage = nil
        if !silent {
            statusMessage = "Checking GitHub Releases…"
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("Retrazo-Mac-App", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 15

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw updateError("GitHub returned an invalid response.")
            }

            if httpResponse.statusCode == 404 {
                throw updateError("No GitHub Release has been published yet.")
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                throw updateError("GitHub update check failed (HTTP \(httpResponse.statusCode)).")
            }

            let release = try JSONDecoder().decode(AppReleaseInfo.self, from: data)
            latestRelease = release
            latestVersion = release.version
            lastCheckDate = Date()
            isUpdateAvailable = version(release.version, isNewerThan: currentVersion)
            statusMessage = isUpdateAvailable
                ? "Retrazo \(release.version) is available."
                : "Retrazo is up to date."
        } catch {
            errorMessage = error.localizedDescription
            if !silent {
                statusMessage = ""
            }
        }

        isBusy = false
    }

    func downloadAndInstallLatestRelease() async {
        if latestRelease == nil {
            await checkForUpdates()
        }

        guard let release = latestRelease, isUpdateAvailable else { return }
        guard let asset = release.assets.first(where: { $0.name == "Retrazo-macOS.zip" })
                ?? release.assets.first(where: {
                    let name = $0.name.lowercased()
                    return name.contains("retrazo") && name.contains("macos") && name.hasSuffix(".zip")
                }) else {
            errorMessage = "Release \(release.tagName) does not contain Retrazo-macOS.zip."
            return
        }

        let fileManager = FileManager.default
        let updatesDirectory = Constants.Paths.applicationSupportDirectory
            .appendingPathComponent("Updates", isDirectory: true)
        let stagingDirectory = updatesDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        isBusy = true
        errorMessage = nil
        statusMessage = "Downloading Retrazo \(release.version)…"

        do {
            try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)

            var request = URLRequest(url: asset.browserDownloadURL)
            request.setValue("Retrazo-Mac-App", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 120
            let (temporaryURL, response) = try await URLSession.shared.download(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw updateError("The update download failed.")
            }

            let archiveURL = stagingDirectory.appendingPathComponent(asset.name)
            try fileManager.moveItem(at: temporaryURL, to: archiveURL)
            try verifyDigestIfAvailable(asset.digest, for: archiveURL)

            statusMessage = "Validating the update…"
            try await Self.runProcess(
                executable: "/usr/bin/ditto",
                arguments: ["-x", "-k", archiveURL.path, stagingDirectory.path]
            )

            let newAppURL = stagingDirectory.appendingPathComponent("Retrazo.app", isDirectory: true)
            guard fileManager.fileExists(atPath: newAppURL.path) else {
                throw updateError("The release ZIP does not contain Retrazo.app.")
            }

            try await Self.runProcess(
                executable: "/usr/bin/codesign",
                arguments: ["--verify", "--deep", "--strict", newAppURL.path]
            )

            guard let newBundle = Bundle(url: newAppURL),
                  newBundle.bundleIdentifier == Bundle.main.bundleIdentifier else {
                throw updateError("The downloaded app has an unexpected bundle identifier.")
            }

            let downloadedVersion = newBundle.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String
            guard downloadedVersion == release.version else {
                throw updateError(
                    "The downloaded app is version \(downloadedVersion ?? "unknown"), not \(release.version)."
                )
            }

            let currentAppURL = Bundle.main.bundleURL.standardizedFileURL
            guard currentAppURL.pathExtension.lowercased() == "app" else {
                throw updateError("Run Retrazo from its .app bundle before installing updates.")
            }

            let parentDirectory = currentAppURL.deletingLastPathComponent()
            guard fileManager.isWritableFile(atPath: parentDirectory.path) else {
                throw updateError("Retrazo cannot update this location. Move it to a writable Applications folder and try again.")
            }

            statusMessage = "Installing and relaunching…"
            try launchInstallerHelper(
                newAppURL: newAppURL,
                currentAppURL: currentAppURL,
                stagingDirectory: stagingDirectory
            )

            NSApp.terminate(nil)
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = ""
            isBusy = false
            try? fileManager.removeItem(at: stagingDirectory)
        }
    }

    func openReleasesPage() {
        guard let url = URL(string: Constants.URLs.appReleasesPage) else { return }
        NSWorkspace.shared.open(url)
    }

    private func version(_ candidate: String, isNewerThan installed: String) -> Bool {
        normalizedVersion(candidate).compare(
            normalizedVersion(installed),
            options: .numeric
        ) == .orderedDescending
    }

    private func normalizedVersion(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
    }

    private func verifyDigestIfAvailable(_ digest: String?, for fileURL: URL) throws {
        guard let digest, digest.lowercased().hasPrefix("sha256:") else { return }
        let expected = String(digest.dropFirst("sha256:".count)).lowercased()
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actual == expected else {
            throw updateError("The downloaded update failed its SHA-256 integrity check.")
        }
    }

    private func launchInstallerHelper(
        newAppURL: URL,
        currentAppURL: URL,
        stagingDirectory: URL
    ) throws {
        let backupURL = currentAppURL.deletingLastPathComponent()
            .appendingPathComponent(".Retrazo-update-backup-\(UUID().uuidString).app")
        let script = """
        pid="$1"
        source_app="$2"
        target_app="$3"
        backup_app="$4"
        staging_dir="$5"
        while kill -0 "$pid" 2>/dev/null; do sleep 0.2; done
        if /bin/mv "$target_app" "$backup_app"; then
            if /bin/mv "$source_app" "$target_app"; then
                /usr/bin/open "$target_app"
                /bin/rm -rf "$backup_app" "$staging_dir"
                exit 0
            fi
            /bin/mv "$backup_app" "$target_app"
        fi
        /usr/bin/open "$target_app"
        exit 1
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c", script, "retrazo-updater",
            String(ProcessInfo.processInfo.processIdentifier),
            newAppURL.path,
            currentAppURL.path,
            backupURL.path,
            stagingDirectory.path
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    nonisolated private static func runProcess(
        executable: String,
        arguments: [String]
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let errorPipe = Pipe()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                process.standardOutput = FileHandle.nullDevice
                process.standardError = errorPipe

                do {
                    try process.run()
                    process.waitUntilExit()
                    if process.terminationStatus == 0 {
                        continuation.resume(returning: ())
                    } else {
                        let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let message = String(data: data, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        continuation.resume(throwing: updateError(
                            message?.isEmpty == false ? message! : "Update validation failed."
                        ))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    nonisolated private static func updateError(_ message: String) -> NSError {
        NSError(
            domain: "AppUpdateManager",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private func updateError(_ message: String) -> NSError {
        Self.updateError(message)
    }
}
