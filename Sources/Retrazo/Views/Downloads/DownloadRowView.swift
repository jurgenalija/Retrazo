import SwiftUI
import AppKit

struct DownloadRowView: View, Equatable {
    let item: DownloadItem
    private let queueManager = DownloadQueueManager.shared
    private let appState = AppState.shared

    static func == (lhs: DownloadRowView, rhs: DownloadRowView) -> Bool {
        lhs.item == rhs.item
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Thumbnail / Icon
            thumbnailView
                .frame(width: 80, height: 50)
                .cornerRadius(6)
                .clipped()
            
            // Middle Content: Title, metadata, progress bar, stats
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    FormatBadge(preset: item.preset)
                    StatusBadge(status: item.status)
                }
                
                if let uploader = item.uploader, !uploader.isEmpty {
                    Text(uploader)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Progress Bar
                if item.status.isActive {
                    ProgressView(value: item.progress)
                        .progressViewStyle(.linear)
                    
                    // Stats Row: Speed, ETA, Size, Percent
                    HStack {
                        if !item.speed.isEmpty {
                            Text(item.speed)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                        if !item.eta.isEmpty {
                            Text("•  ETA \(item.eta)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(item.formattedSizeInfo)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Text(String(format: "%.1f%%", item.progress * 100))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.accentColor)
                    }
                } else if item.status == .failed, let error = item.errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .lineLimit(2)
                } else if item.status == .finished {
                    HStack {
                        Text("Download finished")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                        
                        Spacer()
                        
                        if let output = item.outputPath {
                            Text(URL(fileURLWithPath: output).lastPathComponent)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            
            // Action Buttons
            HStack(spacing: 6) {
                if item.status.isActive {
                    Button(action: {
                        queueManager.cancel(id: item.id)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .help("Cancel Download")
                } else if item.status == .failed || item.status == .cancelled {
                    Button(action: {
                        queueManager.retry(item: item)
                    }) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .help("Retry")
                    
                    Button(action: {
                        queueManager.removeActive(id: item.id)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .help("Remove")
                } else if item.status == .finished {
                    if let path = item.outputPath, FileManager.default.fileExists(atPath: path) {
                        Button(action: {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                        }) {
                            Image(systemName: "folder")
                                .foregroundColor(.accentColor)
                                .font(.system(size: 15))
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
                        .help("Open File")
                    }
                }
                
                // Inspect logs button
                Button(action: {
                    appState.presentLogs(for: item)
                }) {
                    Image(systemName: "terminal")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("View Output Logs")
            }
            .padding(.leading, 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var thumbnailView: some View {
        ZStack(alignment: .bottomTrailing) {
            if let thumb = item.thumbnailUrl, let url = URL(string: thumb) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        fallbackThumbnail
                    @unknown default:
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
    }
    
    private var fallbackThumbnail: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.15))
            .overlay(
                Image(systemName: item.preset.type.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            )
    }
}
