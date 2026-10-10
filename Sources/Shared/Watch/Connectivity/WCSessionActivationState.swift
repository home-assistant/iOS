#if !canImport(WatchConnectivity)
import Foundation

/// WatchConnectivity does not exist on macOS. This stands in for the framework's activation state, which the
/// session abstraction names, so the connectivity layer still compiles there.
public enum WCSessionActivationState: Int {
    case notActivated
    case inactive
    case activated
}
#endif
