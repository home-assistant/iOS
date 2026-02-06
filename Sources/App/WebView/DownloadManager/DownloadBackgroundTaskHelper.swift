import Foundation
import UIKit
import Shared

/// Helper to manage background task assertions for downloads
final class DownloadBackgroundTaskHelper {
    private var taskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private let taskName = "DownloadInBackground"
    private var expirationHandler: (() -> Void)?
    
    func beginBackgroundTask(onExpiration: (() -> Void)? = nil) {
        guard taskIdentifier == .invalid else {
            Current.Log.info("Background task already active for download")
            return
        }
        
        expirationHandler = onExpiration
        
        taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: taskName) { [weak self] in
            guard let self else { return }
            Current.Log.warning("Background task expiring for download")
            
            // Call user expiration handler first
            self.expirationHandler?()
            
            // Must call endBackgroundTask to properly end the task per Apple documentation
            if self.taskIdentifier != .invalid {
                UIApplication.shared.endBackgroundTask(self.taskIdentifier)
                self.taskIdentifier = .invalid
            }
        }
        
        if taskIdentifier != .invalid {
            Current.Log.info("Started background task for download continuation")
        } else {
            Current.Log.warning("Failed to start background task for download")
        }
    }
    
    func endBackgroundTask() {
        guard taskIdentifier != .invalid else { return }
        
        Current.Log.info("Ending background task for download")
        UIApplication.shared.endBackgroundTask(taskIdentifier)
        taskIdentifier = .invalid
    }
    
    deinit {
        endBackgroundTask()
    }
}
