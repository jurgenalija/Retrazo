import Foundation
import UserNotifications
import AppKit

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }
    
    func notifyDownloadCompleted(item: DownloadItem) {
        guard AppSettings.shared.soundNotifications else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Download Complete"
        content.body = item.title
        content.sound = .default
        
        if let path = item.outputPath {
            content.userInfo = ["filePath": path]
        }
        
        let request = UNNotificationRequest(
            identifier: item.id.uuidString,
            content: content,
            trigger: nil // deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error posting completion notification: \(error)")
            }
        }
    }
    
    func notifyDownloadFailed(item: DownloadItem, error: String) {
        guard AppSettings.shared.soundNotifications else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Download Failed"
        content.body = "\(item.title): \(error)"
        content.sound = .defaultCritical
        
        let request = UNNotificationRequest(
            identifier: "\(item.id.uuidString)-error",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
