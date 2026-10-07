import Foundation

/// Where one side of a spoken Assist exchange is handled: by the pipeline on the server, or by
/// Apple's speech frameworks on this device.
public enum AssistSpeechEngine: Equatable {
    case server
    case onDevice
}
