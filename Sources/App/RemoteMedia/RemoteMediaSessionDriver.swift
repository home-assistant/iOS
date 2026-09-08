#if !targetEnvironment(macCatalyst)
import Shared

@available(iOS 27.0, *)
@MainActor
protocol RemoteMediaSessionDriver {
    func publish(_ snapshot: RemoteMediaSnapshot?) async throws
}
#endif
