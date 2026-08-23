import SwiftUI

struct BinaryUpdaterView: View {
    @ObservedObject var binaryManager = BinaryManager.shared
    @ObservedObject var appUpdateManager = AppUpdateManager.shared
    @ObservedObject var settings = AppSettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            appUpdateCard

            // yt-dlp Engine Card
            GroupBox(label: Label("yt-dlp Engine", systemImage: "bolt.fill")) {
                VStack(alignment: .leading, spacing: 14) {
                    // Status row
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: ytdlpStatusIcon)
                            .font(.system(size: 28))
                            .foregroundColor(ytdlpStatusColor)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(ytdlpStatusTitle)
                                .font(.system(size: 14, weight: .semibold))
                            
                            if let cur = binaryManager.currentVersion {
                                Text("Installed Version: \(cur)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let path = binaryManager.resolvedYtDlpPath() {
                                Text("Location: \(path)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        // Action buttons
                        VStack(alignment: .trailing, spacing: 6) {
                            Button(action: {
                                Task {
                                    await binaryManager.checkForUpdates()
                                }
                            }) {
                                Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .disabled(binaryManager.isUpdating)
                            
                            if binaryManager.isUpdateAvailable || binaryManager.currentVersion == nil {
                                Button(action: {
                                    Task {
                                        await binaryManager.downloadOrUpdateYtDlp()
                                    }
                                }) {
                                    Label(binaryManager.currentVersion == nil ? "Install yt-dlp" : "Update to \(binaryManager.latestVersion ?? "Latest")", systemImage: "arrow.down.circle.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(binaryManager.isUpdating)
                            }
                        }
                    }
                    
                    // Updating progress
                    if binaryManager.isUpdating {
                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: binaryManager.updateProgress > 0 ? binaryManager.updateProgress : nil)
                                .progressViewStyle(.linear)
                            Text(binaryManager.updateStatusMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                    
                    Divider()
                    
                    // Release Notes / Info (if available)
                    if let release = binaryManager.releaseInfo {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Latest Release: **\(release.tagName)**")
                                    .font(.caption)
                                Spacer()
                                Text("Released: \(release.formattedDate)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let body = release.body, !body.isEmpty {
                                ScrollView {
                                    Text(body.prefix(1000) + (body.count > 1000 ? "..." : ""))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(height: 90)
                                .padding(8)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                            }
                        }
                    }
                    
                    // Auto check toggle
                    Toggle("Automatically check for yt-dlp updates on startup", isOn: $settings.autoCheckYtDlpUpdates)
                        .font(.system(size: 12))
                }
                .padding(10)
            }
            
            // FFmpeg Engine Card
            GroupBox(label: Label("FFmpeg Post-Processor", systemImage: "waveform.badge.magnifyingglass")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: binaryManager.isFfmpegInstalled ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(binaryManager.isFfmpegInstalled ? .green : .orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(binaryManager.isFfmpegInstalled ? "FFmpeg is Installed" : "FFmpeg is Not Installed")
                                .font(.system(size: 13, weight: .semibold))
                            
                            if let path = binaryManager.ffmpegPath {
                                Text("Location: \(path)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("FFmpeg is recommended for combining high-res video+audio and audio conversion.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button("Re-check") {
                            Task {
                                await binaryManager.checkFfmpeg()
                            }
                        }
                        .controlSize(.small)
                    }
                    
                    if !binaryManager.isFfmpegInstalled {
                        HStack {
                            Text("To install FFmpeg, run in Terminal:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("brew install ffmpeg")
                                .font(.system(size: 11, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding(10)
            }
        }
    }

    private var appUpdateCard: some View {
        GroupBox(label: Label("Retrazo App", systemImage: "shippingbox.fill")) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: appUpdateStatusIcon)
                        .font(.system(size: 28))
                        .foregroundColor(appUpdateStatusColor)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(appUpdateStatusTitle)
                            .font(.system(size: 14, weight: .semibold))

                        Text("Installed Version: \(appUpdateManager.currentVersion)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let release = appUpdateManager.latestRelease {
                            Text("Latest Release: \(release.tagName)\(release.formattedDate.isEmpty ? "" : " • \(release.formattedDate)")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Button {
                            Task { await appUpdateManager.checkForUpdates() }
                        } label: {
                            Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(appUpdateManager.isBusy)

                        if appUpdateManager.isUpdateAvailable {
                            Button {
                                Task { await appUpdateManager.downloadAndInstallLatestRelease() }
                            } label: {
                                Label("Download & Install", systemImage: "arrow.down.app.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(appUpdateManager.isBusy)
                        }
                    }
                }

                if appUpdateManager.isBusy {
                    VStack(alignment: .leading, spacing: 5) {
                        ProgressView()
                            .progressViewStyle(.linear)
                        Text(appUpdateManager.statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if let error = appUpdateManager.errorMessage {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error)
                        Spacer()
                        Button("Open Releases") {
                            appUpdateManager.openReleasesPage()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                } else if !appUpdateManager.statusMessage.isEmpty {
                    Text(appUpdateManager.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let notes = appUpdateManager.latestRelease?.body, !notes.isEmpty {
                    DisclosureGroup("Release Notes") {
                        Text(notes.prefix(1_500) + (notes.count > 1_500 ? "…" : ""))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                            .padding(.top, 5)
                    }
                }

                Toggle("Automatically check for Retrazo updates on startup", isOn: $settings.autoCheckAppUpdates)
                    .font(.system(size: 12))
            }
            .padding(10)
        }
    }

    private var appUpdateStatusTitle: String {
        if appUpdateManager.isBusy {
            return appUpdateManager.statusMessage.isEmpty ? "Checking for Retrazo updates…" : appUpdateManager.statusMessage
        }
        if appUpdateManager.errorMessage != nil {
            return "Could not check for Retrazo updates"
        }
        if appUpdateManager.isUpdateAvailable {
            return "Retrazo \(appUpdateManager.latestVersion ?? "") is available"
        }
        if appUpdateManager.latestRelease == nil {
            return "Updates have not been checked"
        }
        return "Retrazo is up to date"
    }

    private var appUpdateStatusIcon: String {
        if appUpdateManager.isBusy { return "clock.arrow.circlepath" }
        if appUpdateManager.errorMessage != nil { return "exclamationmark.triangle.fill" }
        if appUpdateManager.isUpdateAvailable { return "arrow.down.app.fill" }
        if appUpdateManager.latestRelease == nil { return "questionmark.circle.fill" }
        return "checkmark.seal.fill"
    }

    private var appUpdateStatusColor: Color {
        if appUpdateManager.isBusy { return .yellow }
        if appUpdateManager.errorMessage != nil { return .orange }
        if appUpdateManager.isUpdateAvailable { return .orange }
        if appUpdateManager.latestRelease == nil { return .secondary }
        return .green
    }
    
    private var ytdlpStatusIcon: String {
        switch binaryManager.ytDlpStatus {
        case .installed:
            return binaryManager.isUpdateAvailable ? "arrow.triangle.2.circlepath.circle.fill" : "checkmark.circle.fill"
        case .checking:
            return "clock.fill"
        case .notInstalled:
            return "arrow.down.circle.fill"
        case .error:
            return "exclamationmark.circle.fill"
        }
    }
    
    private var ytdlpStatusColor: Color {
        switch binaryManager.ytDlpStatus {
        case .installed:
            return binaryManager.isUpdateAvailable ? .orange : .green
        case .checking:
            return .yellow
        case .notInstalled, .error:
            return .red
        }
    }
    
    private var ytdlpStatusTitle: String {
        switch binaryManager.ytDlpStatus {
        case .installed:
            return binaryManager.isUpdateAvailable ? "Update Available (v\(binaryManager.latestVersion ?? ""))" : "yt-dlp is up to date"
        case .checking:
            return "Checking yt-dlp Status..."
        case .notInstalled:
            return "yt-dlp is not installed"
        case .error(let msg):
            return "Error: \(msg)"
        }
    }
}
