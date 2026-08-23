import SwiftUI
import AppKit

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // App Icon
            Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
                .resizable()
                .frame(width: 100, height: 100)
                .cornerRadius(22)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            
            VStack(spacing: 6) {
                Text(Constants.appName)
                    .font(.system(size: 24, weight: .bold))
                
                Text("Version \(Constants.appVersion)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("A modern, fast, and native macOS frontend for yt-dlp.\nDownload videos, extract audio, playlists, subtitles, and metadata effortlessly.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
                .lineSpacing(3)
            
            Divider()
                .frame(width: 300)
            
            HStack(spacing: 16) {
                Button(action: {
                    if let url = URL(string: "https://github.com/yt-dlp/yt-dlp") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Label("yt-dlp Project", systemImage: "arrow.up.right.square")
                }
                
                Button(action: {
                    if let url = URL(string: "https://ffmpeg.org") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Label("FFmpeg", systemImage: "arrow.up.right.square")
                }
            }
            
            Text("Built natively in Swift for macOS.")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
