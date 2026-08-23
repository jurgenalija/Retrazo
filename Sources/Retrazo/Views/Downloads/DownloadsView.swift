import SwiftUI
import AppKit

struct DownloadsView: View {
    @ObservedObject var queueManager = DownloadQueueManager.shared
    @ObservedObject var appState = AppState.shared
    
    var body: some View {
        VStack(spacing: 0) {
            downloadComposer
            
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
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Download Composer
    
    private var downloadComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Add a download", systemImage: "plus.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Text("Video, audio, or playlist")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 10) {
                Image(systemName: "link")
                    .foregroundColor(.secondary)

                TextField("Paste a media link", text: $appState.quickURLText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .onSubmit(reviewDownload)

                if hasQuickURL {
                    Button {
                        appState.quickURLText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear link")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9))

            HStack(spacing: 12) {
                Text(hasQuickURL
                     ? "Next, choose from the qualities available for this link."
                     : "Paste directly here, or let Retrazo use your clipboard.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: hasQuickURL ? reviewDownload : pasteAndReview) {
                    Label(
                        hasQuickURL ? "Choose Format" : "Paste Link & Continue",
                        systemImage: hasQuickURL ? "slider.horizontal.3" : "doc.on.clipboard"
                    )
                    .frame(minWidth: 142)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                )
        )
        .padding(16)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "link.badge.plus")
                .font(.system(size: 42, weight: .light))
                .foregroundColor(.accentColor.opacity(0.75))
            
            VStack(spacing: 6) {
                Text("Ready for a link")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Retrazo checks the source first, then shows only the video qualities that are actually available.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            HStack(spacing: 18) {
                Label("1. Paste link", systemImage: "doc.on.clipboard")
                Label("2. Choose quality", systemImage: "checklist")
                Label("3. Download", systemImage: "arrow.down")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 4)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.3))
    }

    private var hasQuickURL: Bool {
        !appState.quickURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func reviewDownload() {
        guard hasQuickURL else { return }
        appState.presentNewDownload(prefill: appState.quickURLText)
    }

    private func pasteAndReview() {
        guard let clipboardText = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !clipboardText.isEmpty else {
            appState.showAlert(
                title: "No Link on Clipboard",
                message: "Copy a media link, then try again."
            )
            return
        }

        appState.quickURLText = clipboardText
        appState.presentNewDownload(prefill: clipboardText)
    }
}
