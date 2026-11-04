import Foundation

/// Source-compatibility alias for the migration off the `Communicator` pod. Call sites keep using
/// `Communicator.shared.…`; it now resolves to the in-house `WatchConnectivityManager`. Message/context
/// value types are referenced explicitly as `HAWatchConnectivity.…` at their (few) construction sites,
/// and `Reachability`/`WatchState` are reached via `Communicator.shared.currentReachability` /
/// `currentWatchState` — so no bare-type aliases are introduced (avoids colliding with the
/// `Reachability` networking pod).
public typealias Communicator = WatchConnectivityManager
