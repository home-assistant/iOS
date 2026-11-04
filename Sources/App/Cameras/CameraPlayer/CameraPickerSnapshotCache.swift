import Foundation
import Shared
import UIKit

@MainActor
final class CameraPickerSnapshotCache {
    static let shared = CameraPickerSnapshotCache()

    struct Key: Hashable {
        let serverId: String
        let entityId: String
    }

    private let failureRetryInterval: TimeInterval
    private var images: [Key: UIImage] = [:]
    private var failures: [Key: Date] = [:]

    init(failureRetryInterval: TimeInterval = 5 * 60) {
        self.failureRetryInterval = failureRetryInterval
    }

    func image(for key: Key) -> UIImage? {
        images[key]
    }

    func shouldFetch(_ key: Key) -> Bool {
        guard images[key] == nil else { return false }
        guard let failedAt = failures[key] else { return true }
        return Current.date().timeIntervalSince(failedAt) >= failureRetryInterval
    }

    func store(_ image: UIImage, for key: Key) {
        images[key] = image
        failures[key] = nil
    }

    func recordFailure(for key: Key) {
        failures[key] = Current.date()
    }
}
