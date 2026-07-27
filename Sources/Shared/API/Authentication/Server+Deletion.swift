#if os(iOS)
import Foundation
import HAKit
import HANetworking
import PromiseKit

public extension Server {
    @MainActor
    func deleteFromApp(minimumDuration: TimeInterval = 0) async {
        let waitAtLeast = after(seconds: minimumDuration)

        let revocations = [Current.api(for: self)?.tokenManager.revokeToken()].compactMap { $0 }
        await race(
            when(resolved: revocations).asVoid(),
            after(seconds: 10.0)
        ).async()

        await waitAtLeast.async()

        Current.api(for: self)?.connection.disconnect()
        Current.servers.remove(identifier: identifier)
        Current.resetAPICache(for: [identifier])
        Current.onboardingObservation.needed(.logout)
    }
}
#endif
