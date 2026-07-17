import BackgroundTasks
import Foundation
import Shared

/// Schedules background Reminders syncs through `BGTaskScheduler` at the frequency the user
/// picked in the sync settings. The frequency is only the earliest allowed start; iOS decides
/// when (and whether) the refresh actually runs.
enum RemindersSyncBackgroundRefresher {
    static let taskIdentifier = "io.robbie.homeassistant.reminderssync"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: .main) { task in
            handleAppRefresh(task: task)
        }
    }

    /// (Re)submits the refresh request, or cancels it when background refresh is off or there is
    /// nothing to sync.
    static func schedule() {
        let interval = RemindersSyncSettings.current.backgroundRefreshInterval
        guard interval > 0, !RemindersSyncConfig.all().isEmpty else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
            return
        }

        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Current.date().addingTimeInterval(interval)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch let error as BGTaskScheduler.Error where error.code == .unavailable {
            Current.Log.info("Reminders sync background refresh unavailable, skipping schedule: \(error)")
        } catch {
            Current.Log.error("Unable to schedule reminders sync background refresh: \(error)")
        }
    }

    private static func handleAppRefresh(task: BGTask) {
        schedule()

        let syncTask = Task { @MainActor in
            await RemindersSyncManager.shared.syncAll()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            syncTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
