import Foundation

public extension HAWatchConnectivity {
    /// Latest-wins application context. The most-recently sent/received context is read from the live
    /// WatchConnectivity caches via `WatchConnectivityManager`, not stored here.
    struct Context {
        public let content: Content

        public init(content: Content = [:]) {
            self.content = content
        }
    }
}
