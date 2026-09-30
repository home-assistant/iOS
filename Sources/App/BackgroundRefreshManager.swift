#if os(iOS)
import BackgroundTasks
#endif
import Foundation
import PromiseKit
import Shared
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum BackgroundRefreshManager {
    static let taskIdentifier = "io.robbie.homeassistant.backgroundfetch"

    private static let earliestBeginInterval: TimeInterval = 15 * 60

    #if os(macOS)
    // A Mac app is never suspended, so nothing has to wake it to refresh: the periodic update timer keeps
    // running for as long as the app does. These exist so the launch sequence reads the same on both
    // platforms.
    static func register() {}

    static func scheduleAppRefresh() {}
    #else
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: .main) { task in
            handleAppRefresh(task: task)
        }
    }

    static func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Current.date().addingTimeInterval(earliestBeginInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch let error as BGTaskScheduler.Error where error.code == .unavailable {
            Current.Log.info("Background app refresh unavailable, skipping schedule: \(error)")
        } catch {
            Current.Log.error("Unable to schedule background app refresh: \(error)")
        }
    }

    private static func handleAppRefresh(task: BGTask) {
        scheduleAppRefresh()

        Current.clientEventStore.addEvent(ClientEvent(text: "Background fetch activated", type: .backgroundOperation))

        var didComplete = false
        func complete(_ success: Bool) {
            DispatchQueue.main.async {
                guard !didComplete else { return }
                didComplete = true
                task.setTaskCompleted(success: success)
            }
        }

        task.expirationHandler = {
            complete(false)
        }

        Current.backgroundTask(withName: BackgroundTask.backgroundFetch.rawValue) { remaining in
            let updatePromise: Promise<Void>
            if Current.settingsStore.isLocationEnabled(for: ApplicationState.current),
               Current.settingsStore.locationSources.backgroundFetch {
                updatePromise = firstly {
                    Current.location.oneShotLocation(.BackgroundFetch, remaining)
                }.then { location in
                    when(fulfilled: Current.apis.map {
                        $0.SubmitLocation(updateType: .BackgroundFetch, location: location, zone: nil)
                    })
                }.asVoid()
            } else {
                updatePromise = when(fulfilled: Current.apis.map {
                    $0.UpdateSensors(trigger: .BackgroundFetch, location: nil)
                })
            }

            return updatePromise
        }.done {
            complete(true)
        }.catch { error in
            Current.Log.error("Error when attempting to update data during background fetch: \(error)")
            complete(false)
        }
    }
    #endif
}
