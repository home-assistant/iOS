import Foundation

/// Everything a connection reports back to the manager that owns it.
enum SendspinConnectionEvent {
    case connected(serverName: String, serverId: String, trust: SendspinTrustLevel)
    case rolesActivated(Set<SendspinRole>)
    case clockSynchronized
    case metadata(SendspinTrackMetadata?)
    case controller(SendspinControllerState?)
    case group(SendspinGroupState)
    case playerVolume(volume: Int, muted: Bool)
    case outputDelay(milliseconds: Int)
    case streamFormat(SendspinAudioFormat?)
    case paired(serverId: String)
    case unpaired(serverId: String)
    case closed(Error?)
}
