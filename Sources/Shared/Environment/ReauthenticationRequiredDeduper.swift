import Foundation

/// Collapses TokenManager + HAAPI reporting the same revoked refresh token into one notification.
final class ReauthenticationRequiredDeduper {
    private enum Constants {
        static let window: TimeInterval = 2
    }

    private let date: () -> Date
    private var last: (serverId: String, at: Date)?

    init(date: @escaping () -> Date) {
        self.date = date
    }

    func shouldNotify(serverId: String) -> Bool {
        let now = date()
        if let last, last.serverId == serverId, now.timeIntervalSince(last.at) < Constants.window {
            return false
        }
        last = (serverId, now)
        return true
    }
}
