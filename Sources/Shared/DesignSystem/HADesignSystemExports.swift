@_exported import HADesignSystem

// Re-exports of the local packages `Shared` is being split into, so the ~470 files that `import Shared`
// keep resolving these symbols unchanged.
//
// `HAIconic` (MaterialDesignIcons + font) is cross-platform. `HAUtilities` (haptics) is linked only into
// `Shared-iOS`, which builds for iOS and macOS, so its re-export is guarded to keep `Shared-watchOS` building.
@_exported import HAIconic
@_exported import HAModels
@_exported import HANetworking
@_exported import HAWatchCommunicationMessages
#if !os(watchOS)
@_exported import HAUtilities
#endif
