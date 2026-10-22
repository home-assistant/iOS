import Foundation

enum WebRTCClientMedia {
    case playback
    case microphone

    var recordsMicrophone: Bool {
        self != .playback
    }
}
