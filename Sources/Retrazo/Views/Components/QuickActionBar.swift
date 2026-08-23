import SwiftUI

struct QuickActionBar: View {
    @ObservedObject var queueManager = DownloadQueueManager.shared
    @ObservedObject var binaryManager = BinaryManager.shared
    @ObservedObject var appState = AppState.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Engine status indicator
            engineStatusPill
            
            Spacer()
            
            // Queue Actions
            if !queueManager.activeDownloads.isEmpty {
                Button(action: {
                    queueManager.clearCompleted()
                }) {
                    Label("Clear Completed", systemImage: "xmark.bin")
                }
                .buttonStyle(.borderless)
                .font(.caption)
                
                Button(action: {
                    queueManager.cancelAll()
                }) {
                    Label("Cancel All", systemImage: "stop.circle")
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    @ViewBuilder
    private var engineStatusPill: some View {
        Button(action: {
            appState.selectedTab = .settings
        }) {
            HStack(spacing: 6) {
                Circle()
                    .fill(engineColor)
                    .frame(width: 8, height: 8)
                
                Text(engineLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                if binaryManager.isUpdateAvailable {
                    Text("Update")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    private var engineColor: Color {
        switch binaryManager.ytDlpStatus {
        case .installed:
            return binaryManager.isUpdateAvailable ? .orange : .green
        case .checking:
            return .yellow
        case .notInstalled, .error:
            return .red
        }
    }
    
    private var engineLabel: String {
        switch binaryManager.ytDlpStatus {
        case .installed(let version, _):
            return "yt-dlp \(version)"
        case .checking:
            return "Checking yt-dlp..."
        case .notInstalled:
            return "yt-dlp Not Found"
        case .error:
            return "yt-dlp Error"
        }
    }
}
