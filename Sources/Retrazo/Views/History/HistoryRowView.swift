import SwiftUI
import AppKit

struct HistoryRowView: View {
    let item: DownloadItem
    @ObservedObject var queueManager = DownloadQueueManager.shared
    @ObservedObject var appState = AppState.shared
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Thumbnail / Icon
            ZStack(alignment: .bottomTrailing) {
                if let thumb = item.thumbnailUrl, let url = URL(string: thumb) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().aspectRatio(contentMode: .fill)
                        default:
                            fallbackThumbnail
                        }
                    }
                } else {
                    fallbackThumbnail
                }
                
                if let duration = item.duration, duration > 0 {
                    Text(item.formattedDuration)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(3)
                        .padding(3)
                }
            }
            .frame(width: 80, height: 50)
            .cornerRadius(6)
            .clipped()
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    FormatBadge(preset: item.preset)
                    StatusBadge(status: item.status)
                }
                
                HStack(spacing: 8) {
                    if let uploader = item.uploader, !uploader.isEmpty {
                        Text(uploader)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    if let completed = item.completedAt {
                        Text("•  \(formattedDate(completed))")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    if item.totalBytes > 0 {
                        Text("•  \(ByteCountFormatter.string(fromByteCount: item.totalBytes, countStyle: .file))")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                if let out = item.outputPath {
                    Text(out)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }
            
            // Actions
            HStack(spacing: 8) {
                if let path = item.outputPath, FileManager.default.fileExists(atPath: path) {
                    Button(action: {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                    }) {
                        Image(systemName: "folder")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .help("Show in Finder")
                    
                    Button(action: {
                        NSWorkspace.shared.open(URL(fileURLWithPath: path))
                    }) {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .help("Play File")
                }
                
                Button(action: {
                    queueManager.retry(item: item)
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("Re-download")
                
                Button(action: {
                    appState.presentLogs(for: item)
                }) {
                    Image(systemName: "terminal")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("View Logs")
                
                Button(action: {
                    queueManager.removeHistoryItem(id: item.id)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("Delete from History")
            }
            .padding(.leading, 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var fallbackThumbnail: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.12))
            .overlay(
                Image(systemName: item.preset.type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            )
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
