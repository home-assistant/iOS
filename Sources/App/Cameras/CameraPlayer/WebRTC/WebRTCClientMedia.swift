import Foundation

enum WebRTCClientMedia {
    case playback
    case microphone
    case call

    var recordsMicrophone: Bool {
        self != .playback
    }
}
