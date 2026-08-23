import SwiftUI
import AppKit

struct LogSheetView: View {
    let item: DownloadItem
    @Environment(\.dismiss) private var dismiss
    @State private var filterText = ""
    
    var filteredLogs: [String] {
        if filterText.isEmpty {
            return item.logs
        }
        return item.logs.filter { $0.localizedCaseInsensitiveContains(filterText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("yt-dlp Execution Log")
                        .font(.headline)
                    Text(item.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Copy all logs button
                Button(action: {
                    let allLogs = item.logs.joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(allLogs, forType: .string)
                }) {
                    Label("Copy Logs", systemImage: "doc.on.doc")
                }
                .controlSize(.small)
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Search Filter Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Filter log output...", text: $filterText)
                    .textFieldStyle(.plain)
                
                if !filterText.isEmpty {
                    Button(action: { filterText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Log Content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        if filteredLogs.isEmpty {
                            Text("No log entries recorded yet.")
                                .foregroundColor(.secondary)
                                .italic()
                                .padding()
                        } else {
                            ForEach(Array(filteredLogs.enumerated()), id: \.offset) { idx, line in
                                Text(line)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(colorForLine(line))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(idx)
                            }
                        }
                    }
                    .padding(12)
                }
                .background(Color.black.opacity(0.92))
            }
        }
        .frame(minWidth: 650, minHeight: 450)
    }
    
    private func colorForLine(_ line: String) -> Color {
        if line.contains("ERROR:") || line.contains("Error:") || line.contains("failed") {
            return .red
        } else if line.contains("WARNING:") || line.contains("Warning:") {
            return .yellow
        } else if line.contains("[download]") {
            return .green
        } else if line.contains("[Merger]") || line.contains("[ExtractAudio]") {
            return .cyan
        }
        return .white.opacity(0.85)
    }
}
