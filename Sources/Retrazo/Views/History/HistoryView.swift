import SwiftUI

struct HistoryView: View {
    @ObservedObject var queueManager = DownloadQueueManager.shared
    @State private var searchText = ""
    @State private var selectedFilter: HistoryFilter = .all
    
    enum HistoryFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case video = "Videos"
        case audio = "Audio"
        case failed = "Failed"
        
        var id: String { rawValue }
    }
    
    var filteredHistory: [DownloadItem] {
        queueManager.historyDownloads.filter { item in
            let matchesSearch = searchText.isEmpty ||
                item.title.localizedCaseInsensitiveContains(searchText) ||
                (item.uploader?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                item.url.localizedCaseInsensitiveContains(searchText)
            
            guard matchesSearch else { return false }
            
            switch selectedFilter {
            case .all:
                return true
            case .video:
                return item.preset.type == .video && item.status == .finished
            case .audio:
                return item.preset.type == .audio && item.status == .finished
            case .failed:
                return item.status == .failed || item.status == .cancelled
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search history by title, creator, or URL...", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                // Filter Picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(HistoryFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
                
                // Clear History Button
                if !queueManager.historyDownloads.isEmpty {
                    Button(action: {
                        queueManager.clearHistory()
                    }) {
                        Label("Clear All", systemImage: "trash")
                    }
                    .controlSize(.regular)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // List or Empty
            if filteredHistory.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(searchText.isEmpty ? "No Download History Yet" : "No items match '\(searchText)'")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredHistory) { item in
                            HistoryRowView(item: item)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}
