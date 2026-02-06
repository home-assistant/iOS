import Foundation
import UIKit
import Shared

/// Helper to manage background task assertions for downloads
final class DownloadBackgroundTaskHelper {
    private var taskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private let taskName = "DownloadInBackground"
    
    func beginBackgroundTask() {
        guard taskIdentifier == .invalid else {
            Current.Log.info("Background task already active for download")
            return
        }
        
        taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: taskName) { [weak self] in
            self?.endBackgroundTask()
        }
        
        if taskIdentifier != .invalid {
            Current.Log.info("Started background task for download continuation")
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
