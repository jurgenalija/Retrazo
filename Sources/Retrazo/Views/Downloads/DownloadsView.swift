import SwiftUI
import AppKit

struct DownloadsView: View {
    @ObservedObject var queueManager = DownloadQueueManager.shared
    @ObservedObject var appState = AppState.shared
    @ObservedObject var binaryManager = BinaryManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Top URL Input Bar
            topInputBar
            
            Divider()
            
            // Downloads Queue List or Empty State
            if queueManager.activeDownloads.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(queueManager.activeDownloads) { item in
                            DownloadRowView(item: item)
                        }
                    }
                    .padding(16)
                }
            }
            
            Divider()
            
            // Bottom Action Bar
            QuickActionBar()
        }
    }
    
    // MARK: - Top Input Bar
    
    private var topInputBar: some View {
        HStack(spacing: 10) {
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.secondary)
                
                TextField("Enter or paste video URL (YouTube, Vimeo, TikTok, X, etc.)", text: $appState.quickURLText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit {
                        if !appState.quickURLText.trimmingCharacters(in: .whitespaces).isEmpty {
                            appState.presentNewDownload(prefill: appState.quickURLText)
                        }
                    }
                
                if !appState.quickURLText.isEmpty {
                    Button(action: {
                        appState.quickURLText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            
            // Quick Paste button
            Button(action: {
                if let clip = NSPasteboard.general.string(forType: .string) {
                    appState.quickURLText = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                    appState.presentNewDownload(prefill: appState.quickURLText)
                }
            }) {
                Label("Paste", systemImage: "doc.on.clipboard")
            }
            .controlSize(.regular)
            
            // Customize & Download Button
            Button(action: {
                appState.presentNewDownload(prefill: appState.quickURLText)
            }) {
                Label("Download", systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(appState.quickURLText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 6) {
                Text("No Active Downloads")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Paste a URL from YouTube, Vimeo, TikTok, Twitch, or any supported site above to start.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            
            Button(action: {
                if let clip = NSPasteboard.general.string(forType: .string) {
                    appState.presentNewDownload(prefill: clip.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    appState.presentNewDownload()
                }
            }) {
                Label("Add Download from Clipboard", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.3))
    }
}
