#if !canImport(WatchConnectivity)
import Foundation

/// WatchConnectivity does not exist on macOS. This stands in for the framework's delegate protocol, which the
/// session abstraction names, so the connectivity layer still compiles there; with no session to hand it, the
/// manager reports itself as unsupported and every send fails the way it does on an iPad.
public protocol WCSessionDelegate: AnyObject {}
#endif
