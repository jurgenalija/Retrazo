import Foundation
import Combine
import AppKit

@MainActor
class DownloadQueueManager: ObservableObject {
    static let shared = DownloadQueueManager()
    
    @Published var activeDownloads: [DownloadItem] = []
    @Published var historyDownloads: [DownloadItem] = []
    
    private var runningTasks: [UUID: ProcessTask] = [:]
    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()
    private let historyPersistenceQueue = DispatchQueue(
        label: "com.retrazo.history-persistence",
        qos: .utility
    )
    
    init() {
        loadHistory()

        settings.$maxConcurrentDownloads
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.processQueue()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Queue Operations
    
    func enqueue(
        url: String,
        preset: DownloadPreset? = nil,
        customArgs: [String] = [],
        mediaInfo: MediaInfo? = nil,
        optionOverrides: DownloadOptionOverrides? = nil
    ) {
        let activePreset = preset ?? DownloadPreset.defaultPresets.first(where: { $0.id == settings.defaultPresetId }) ?? .bestVideo
        
        let title = mediaInfo?.displayTitle ?? "Preparing download..."
        let uploader = mediaInfo?.displayUploader
        let duration = mediaInfo?.duration
        let thumbnail = mediaInfo?.thumbnail
        
        let item = DownloadItem(
            id: UUID(),
            url: url,
            title: title,
            thumbnailUrl: thumbnail,
            duration: duration,
            uploader: uploader,
            status: .queued,
            formatDescription: activePreset.name,
            customArgs: customArgs,
            preset: activePreset,
            optionOverrides: optionOverrides,
            isPlaylist: mediaInfo?.isPlaylist ?? false,
            playlistCount: mediaInfo?.playlistCount
        )
        
        activeDownloads.insert(item, at: 0)
        processQueue()
    }
    
    func enqueueItem(_ item: DownloadItem) {
        activeDownloads.insert(item, at: 0)
        processQueue()
    }
    
    func cancel(id: UUID) {
        if let task = runningTasks[id] {
            task.cancel()
            runningTasks.removeValue(forKey: id)
        }
        
        if let index = activeDownloads.firstIndex(where: { $0.id == id }) {
            activeDownloads[index].status = .cancelled
            activeDownloads[index].errorMessage = "Cancelled by user"
            moveItemToHistory(activeDownloads[index])
            activeDownloads.remove(at: index)
        }
        
        processQueue()
    }
    
    func retry(item: DownloadItem) {
        var newItem = item
        newItem.id = UUID()
        newItem.status = .queued
        newItem.progress = 0.0
        newItem.speed = ""
        newItem.eta = ""
        newItem.downloadedBytes = 0
        newItem.totalBytes = 0
        newItem.totalBytesEstimated = false
        newItem.outputPath = nil
        newItem.errorMessage = nil
        newItem.logs = []
        newItem.createdAt = Date()
        newItem.completedAt = nil
        
        // Remove from history if retrying from history
        historyDownloads.removeAll(where: { $0.id == item.id })
        saveHistory()
        
        activeDownloads.insert(newItem, at: 0)
        processQueue()
    }
    
    func removeActive(id: UUID) {
        cancel(id: id)
        activeDownloads.removeAll(where: { $0.id == id })
    }
    
    func clearCompleted() {
        let completed = activeDownloads.filter { $0.status.isTerminal }
        for item in completed {
            moveItemToHistory(item)
        }
        activeDownloads.removeAll { $0.status.isTerminal }
    }
    
    func clearHistory() {
        historyDownloads.removeAll()
        saveHistory()
    }
    
    func removeHistoryItem(id: UUID) {
        historyDownloads.removeAll(where: { $0.id == id })
        saveHistory()
    }
    
    func cancelAll() {
        let cancelledIDs = Set(runningTasks.keys)

        for (id, task) in runningTasks {
            task.cancel()
            if let index = activeDownloads.firstIndex(where: { $0.id == id }) {
                activeDownloads[index].status = .cancelled
                activeDownloads[index].errorMessage = "Cancelled by user"
                activeDownloads[index].completedAt = Date()
                moveItemToHistory(activeDownloads[index])
            }
        }
        runningTasks.removeAll()
        activeDownloads.removeAll { cancelledIDs.contains($0.id) }
        processQueue()
    }
    
    // MARK: - Queue Scheduler
    
    func processQueue() {
        let activeCount = activeDownloads.filter { $0.status.isActive }.count
        let availableSlots = max(0, settings.maxConcurrentDownloads - activeCount)
        guard availableSlots > 0 else { return }
        
        let queuedItems = activeDownloads.filter { $0.status == .queued }
        let itemsToStart = queuedItems.prefix(availableSlots)
        
        for item in itemsToStart {
            startItemDownload(id: item.id)
        }
    }
    
    private func startItemDownload(id: UUID) {
        guard let index = activeDownloads.firstIndex(where: { $0.id == id }) else { return }
        let item = activeDownloads[index]
        
        activeDownloads[index].status = .downloading
        
        let task = YtDlpProcessManager.shared.startDownload(
            item: item,
            settings: settings,
            onProgress: { [weak self] progress in
                Task { @MainActor [weak self] in
                    guard let self = self,
                          let idx = self.activeDownloads.firstIndex(where: { $0.id == id }) else { return }
                    
                    self.activeDownloads[idx].progress = progress.progress
                    self.activeDownloads[idx].speed = progress.speed
                    self.activeDownloads[idx].eta = progress.eta
                    self.activeDownloads[idx].downloadedBytes = progress.downloadedBytes
                    self.activeDownloads[idx].totalBytes = progress.totalBytes
                    self.activeDownloads[idx].totalBytesEstimated = progress.totalBytesEstimated
                    self.activeDownloads[idx].status = progress.status
                    if let path = progress.outputPath {
                        self.activeDownloads[idx].outputPath = path
                    }
                }
            },
            onLog: { [weak self] lines in
                Task { @MainActor [weak self] in
                    guard let self = self,
                          let idx = self.activeDownloads.firstIndex(where: { $0.id == id }) else { return }
                    self.activeDownloads[idx].logs.append(contentsOf: lines)
                    // Keep logs manageable
                    if self.activeDownloads[idx].logs.count > 1000 {
                        self.activeDownloads[idx].logs.removeFirst(self.activeDownloads[idx].logs.count - 800)
                    }
                }
            },
            onCompletion: { [weak self] result in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.runningTasks.removeValue(forKey: id)
                    
                    guard let idx = self.activeDownloads.firstIndex(where: { $0.id == id }) else {
                        self.processQueue()
                        return
                    }
                    
                    switch result {
                    case .success(let outputPath):
                        self.activeDownloads[idx].status = .finished
                        self.activeDownloads[idx].progress = 1.0
                        self.activeDownloads[idx].speed = ""
                        self.activeDownloads[idx].eta = ""
                        self.activeDownloads[idx].completedAt = Date()
                        if let path = outputPath {
                            self.activeDownloads[idx].outputPath = path
                        }
                        
                        NotificationManager.shared.notifyDownloadCompleted(item: self.activeDownloads[idx])
                        
                        let completedItem = self.activeDownloads[idx]
                        self.moveItemToHistory(completedItem)
                        self.activeDownloads.remove(at: idx)
                        
                    case .failure(let error):
                        self.activeDownloads[idx].status = .failed
                        self.activeDownloads[idx].errorMessage = error.localizedDescription
                        self.activeDownloads[idx].completedAt = Date()
                        
                        NotificationManager.shared.notifyDownloadFailed(item: self.activeDownloads[idx], error: error.localizedDescription)
                    }
                    
                    self.processQueue()
                }
            }
        )
        
        if let task = task {
            runningTasks[id] = task
        }
    }
    
    // MARK: - History Persistence
    
    private func moveItemToHistory(_ item: DownloadItem) {
        historyDownloads.removeAll(where: { $0.id == item.id })
        historyDownloads.insert(item, at: 0)
        // Keep max 200 history items
        if historyDownloads.count > 200 {
            historyDownloads.removeLast(historyDownloads.count - 200)
        }
        saveHistory()
    }
    
    private func saveHistory() {
        let snapshot = historyDownloads
        historyPersistenceQueue.async {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: Constants.Paths.historyFile, options: .atomic)
            } catch {
                print("Failed to save download history: \(error)")
            }
        }
    }
    
    private func loadHistory() {
        let file = Constants.Paths.historyFile
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        
        do {
            let data = try Data(contentsOf: file)
            self.historyDownloads = try JSONDecoder().decode([DownloadItem].self, from: data)
        } catch {
            print("Failed to load download history: \(error)")
        }
    }
}
