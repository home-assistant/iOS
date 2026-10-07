import Foundation

protocol WatchExtendedRuntimeSessionHolding: AnyObject {
    func begin(_ reason: WatchExtendedRuntimeSessionManager.Reason)
    func end(_ reason: WatchExtendedRuntimeSessionManager.Reason)
}
