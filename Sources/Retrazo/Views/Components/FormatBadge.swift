import SwiftUI

struct FormatBadge: View {
    let preset: DownloadPreset
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: preset.type.icon)
                .font(.system(size: 10))
            
            if preset.extractAudio {
                Text(preset.audioFormat.displayName)
                    .font(.system(size: 11, weight: .semibold))
            } else {
                if let height = preset.customMaxHeight ?? preset.videoQuality.maxHeight {
                    Text("\(height)p")
                        .font(.system(size: 11, weight: .semibold))
                } else {
                    Text(preset.videoContainer.displayName)
                        .font(.system(size: 11, weight: .semibold))
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.12))
        .foregroundColor(.primary)
        .cornerRadius(4)
    }
}
