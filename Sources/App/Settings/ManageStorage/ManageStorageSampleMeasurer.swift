import Foundation

/// Fixed sizes for the SwiftUI preview and the snapshot tests.
///
/// Real measurements depend on whatever the simulator happens to have cached, which would make a
/// reference image change from run to run; this hands the screen the same numbers every time.
struct ManageStorageSampleMeasurer: ManageStorageMeasuring {
    static let byteCounts: [ManageStorageItemID: Int64] = [
        .appDatabase: 12_582_912,
        .appPreferences: 143_360,
        .legacyRealmStore: 4_194_304,
        .notificationSounds: 2_097_152,
        .cachedEntities: 6_291_456,
        .cachedCalendarEvents: 524_288,
        .locationHistory: 1_048_576,
        .widgetCache: 262_144,
        .watchItemCache: 32_768,
        .networkResponseCache: 8_388_608,
        .frontendAssetCache: 41_943_040,
        .websiteData: 3_145_728,
        .clientEventLog: 786_432,
        .notificationHistory: 393_216,
        .logFiles: 15_728_640,
        .downloads: 0,
        .temporaryFiles: 65_536,
    ]

    func byteCount(of item: ManageStorageItem) async -> Int64 {
        Self.byteCounts[item.id] ?? 0
    }
}
