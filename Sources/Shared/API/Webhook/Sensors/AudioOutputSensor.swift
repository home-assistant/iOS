import AVFoundation
import Foundation
import HAKit
import Intents
import PromiseKit

/// iOS AudioOutputSensor
final class AudioOutputSensor: SensorProvider {
    let request: SensorProviderRequest
    init(request: SensorProviderRequest) {
        self.request = request
    }

    func sensors() -> Promise<[WebhookSensor]> {
        var sensors: [WebhookSensor] = []
        #if os(iOS)
        let audioOutput = getAudioOutput().compactMap(\.type).joined(separator: ", ")
        sensors.append(.init(
            name: "Audio Output",
            uniqueID: "iphone-audio-output",
            icon: "mdi:volume-high",
            state: audioOutput
        ))
        #endif
        return .value(sensors)
    }

    #if os(iOS)
    private func getAudioOutput() -> [AudioOutput] {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        return outputs.map { output in
            let type = output.portType
            var audioOutput = AudioOutput(identifier: nil, display: "\(output.portName)")

            switch type {
            case .airPlay:
                audioOutput.type = "airplay"
            case .bluetoothA2DP:
                audioOutput.type = "bluetoothA2DP"
            case .bluetoothHFP:
                audioOutput.type = "bluetoothHFP"
            case .bluetoothLE:
                audioOutput.type = "bluetoothLE"
            case .builtInMic:
                audioOutput.type = "builtInMic"
            case .builtInReceiver:
                audioOutput.type = "builtInReceiver"
            case .builtInSpeaker:
                audioOutput.type = "builtInSpeaker"
            case .carAudio:
                audioOutput.type = "carAudio"
            case .HDMI:
                audioOutput.type = "HDMI"
            case .headphones:
                audioOutput.type = "headphones"
            case .headsetMic:
                audioOutput.type = "headsetMic"
            case .lineIn:
                audioOutput.type = "lineIn"
            case .lineOut:
                audioOutput.type = "lineOut"
            case .usbAudio:
                audioOutput.type = "usbAudio"
            default:
                audioOutput.type = "unknown"
            }
            return audioOutput
        }
    }
    #endif
}

struct AudioOutput {
    var identifier: String?
    var display: String
    var type: String?
}
