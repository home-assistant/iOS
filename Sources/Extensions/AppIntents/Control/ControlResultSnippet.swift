import AppIntents
import Foundation
import HAKit
import Shared

/// Builds the card a control command shows once it has changed something.
///
/// The state is read back from the server rather than assumed: a command reports what the entity
/// *is* now, not what it was told to become, so a light that refused to turn on doesn't show a card
/// claiming otherwise.
@available(macOS 13.0, watchOS 9.4, *)
enum ControlResultSnippet {
    /// How long to keep reading the state back while it is still the one the action replaced. Long
    /// enough for a device to report in, short enough that Siri isn't left waiting on one that never
    /// will.
    static let settleTimeout: TimeInterval = 2
    private static let settleInterval: Duration = .milliseconds(250)

    /// - Parameter expected: the states that would show the action took effect, from
    ///   `Domain.statesAfter(_:)`. Passing them is what keeps a light that was just switched on from
    ///   being drawn as off. Empty reads the state once, for an action that settles on nothing.
    static func state(
        of context: some EntityContextRepresentable,
        serverId: String,
        iconName: String,
        settlingOn expected: [String] = []
    ) async -> HAEntityStateAppEntity? {
        guard let server = Current.servers.server(for: .init(rawValue: serverId)),
              let liveState = await settledState(
                  of: context.entityId,
                  on: server,
                  expecting: expected
              ) else {
            // The command already succeeded; failing to read the state back is not worth failing it,
            // so the spoken sentence stands on its own and no card is shown.
            return nil
        }
        return HAEntityStateAppEntity(
            context: context,
            serverId: serverId,
            serverName: server.info.name,
            iconName: iconName,
            state: liveState
        )
    }

    /// Reads the state back until it is the one the action asked for, or until the deadline passes.
    ///
    /// A service call returns before the device has reported the change, so reading once hands back
    /// the state the action replaced. Whatever the last read said is still what's returned, so a
    /// device that refuses, or one slower than the deadline, reports what it really is rather than
    /// what it was told to become.
    private static func settledState(
        of entityId: String,
        on server: Server,
        expecting expected: [String]
    ) async -> HAEntity? {
        let deadline = Date().addingTimeInterval(settleTimeout)
        var latest: HAEntity?
        repeat {
            guard let read = try? await AppIntentServerAPI.entityState(server: server, entityId: entityId) else {
                return latest
            }
            latest = read
            guard !expected.isEmpty, !expected.contains(read.state) else { return read }
            try? await Task.sleep(for: settleInterval)
        } while Date() < deadline
        return latest
    }
}
