import SwiftUI

struct StatusBadge: View {
    let status: DownloadStatus
    
    var color: Color {
        switch status {
        case .queued:
            return .secondary
        case .analyzing:
            return .orange
        case .downloading:
            return .blue
        case .processing:
            return .purple
        case .paused:
            return .yellow
        case .finished:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .gray
        }
    }
    
    var icon: String {
        switch status {
        case .queued:
            return "clock"
        case .analyzing:
            return "magnifyingglass"
        case .downloading:
            return "arrow.down"
        case .processing:
            return "gearshape.2"
        case .paused:
            return "pause.fill"
        case .finished:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .cancelled:
            return "xmark.circle"
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(status.rawValue)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .clipShape(Capsule())
    }
}
