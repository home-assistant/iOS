#if os(iOS)
import BackgroundTasks
#endif
import Foundation
import Shared

/// Schedules background Reminders syncs at the frequency the user picked in the sync settings.
///
/// On iOS that goes through `BGTaskScheduler`, where the frequency is only the earliest allowed start and
/// the system decides when (and whether) the refresh actually runs. A Mac app is never suspended, so
/// there it is a plain repeating timer that runs for as long as the app does.
enum RemindersSyncBackgroundRefresher {
    static let taskIdentifier = "io.robbie.homeassistant.reminderssync"

    #if os(macOS)
    private static var timer: Timer?

    static func register() {}

    /// (Re)starts the timer, or stops it when background refresh is off or there is nothing to sync.
    static func schedule() {
        timer?.invalidate()
        timer = nil

        let interval = RemindersSyncSettings.current.backgroundRefreshInterval
        guard interval > 0, !RemindersSyncConfig.all().isEmpty else { return }

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                await RemindersSyncManager.shared.syncAll()
            }
        }
    }
    #else
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

        // BGTask completion must be signaled exactly once, and expiration can race the sync.
        var didComplete = false
        func complete(_ success: Bool) {
            DispatchQueue.main.async {
                guard !didComplete else { return }
                didComplete = true
                task.setTaskCompleted(success: success)
            }
        }

        let syncTask = Task { @MainActor in
            await RemindersSyncManager.shared.syncAll()
            complete(!Task.isCancelled)
        }
        task.expirationHandler = {
            syncTask.cancel()
            complete(false)
        }
    }
    #endif
}
