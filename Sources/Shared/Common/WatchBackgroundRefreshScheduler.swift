import Foundation
import PromiseKit
#if os(watchOS)
import WatchKit
#endif

public class WatchBackgroundRefreshScheduler {
    public func schedule() -> Guarantee<Void> {
        #if os(watchOS)
        let (promise, seal) = Guarantee<Void>.pending()

        let date = nextFireDate()

        WKExtension.shared().scheduleBackgroundRefresh(
            withPreferredDate: date,
            userInfo: nil,
            scheduledCompletion: { error in
                Current.Log.info("scheduled for \(date): \(String(describing: error))")
                seal(())
            }
        )

        return promise
        #else
        return .value(())
        #endif
    }

    internal func nextFireDate() -> Date {
        // Apple documents that, if we have an active complication, we can reliably refresh 4 times per hour
        // so we divide this into 0 / 15 / 30 / 45
        let possibleComponents = stride(from: 0, to: 60, by: 15).map { minute in
            with(DateComponents()) {
                $0.minute = minute
            }
        }

        let now = Current.date()

        let nextPossibilities = possibleComponents.compactMap {
            Calendar.current.nextDate(after: now, matching: $0, matchingPolicy: .nextTime)
        }.sorted()

        return nextPossibilities.first ?? now
    }
}
