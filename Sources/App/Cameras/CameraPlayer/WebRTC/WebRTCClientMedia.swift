import Foundation

enum WebRTCClientMedia {
    case playback
    case talkback
    case microphone

    var recordsMicrophone: Bool {
        self != .playback
    }
}
