import AVFoundation
import Combine
import Foundation
import HAKit
import Intents
import PromiseKit

final class iOSAudioOutputSensorUpdateSignaler: SensorProviderUpdateSignaler, SensorObserver {
    /// Indicates where observation is already happening
    private var isObserving = false
    /// Indicates where intial sensors update is going to happen
    private var firstUpdate = true

    private var cancellables: Set<AnyCancellable> = []
    private let signal: () -> Void
    init(signal: @escaping () -> Void) {
        self.signal = signal
        Current.sensors.register(observer: self)
    }

    private func observe() {
        guard !isObserving else { return }
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] _ in
                self?.signal()
            }
            .store(in: &cancellables)
        isObserving = true
    }

    private func stopObserving() {
        guard isObserving else { return }
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        isObserving = false
    }

    func sensorContainer(_ container: SensorContainer, didUpdate update: SensorObserverUpdate) {
        guard firstUpdate else { return }
        firstUpdate = false
        updateObservation(sensorUpdates: update)
    }

    func sensorContainer(_ container: SensorContainer, didSignalForUpdateBecause reason: SensorContainerUpdateReason, lastUpdate: SensorObserverUpdate?) {
        guard reason == .settingsChange else { return }
        updateObservation(sensorUpdates: lastUpdate)
    }

    private func updateObservation(sensorUpdates: SensorObserverUpdate?) {
        sensorUpdates?.sensors.done { [weak self] sensors in
            guard let frontMostAppSensor = sensors.first(where: { sensor in
                sensor.UniqueID == WebhookSensorId.iPhoneAudioOutput.rawValue
            }) else {
                return
            }
            if Current.sensors.isEnabled(sensor: frontMostAppSensor) {
                self?.observe()
            } else {
                self?.stopObserving()
            }
        }
    }
}

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
            uniqueID: WebhookSensorId.iPhoneAudioOutput.rawValue,
            icon: "mdi:volume-high",
            state: audioOutput
        ))
        #endif
        return .value(sensors)
    }

    #if os(iOS)
    private func getAudioOutput() -> [AudioOutput] {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs

        // Set up our observer
        let _: iOSAudioOutputSensorUpdateSignaler = request.dependencies.updateSignaler(for: self)

        return outputs.map { output in
            let type = output.portType
            var audioOutput = AudioOutput(identifier: nil, display: "\(output.portName)")

            switch type {
            case .airPlay:
                audioOutput.type = "AirPlay"
            case .bluetoothA2DP:
                audioOutput.type = "Bluetooth A2DP"
            case .bluetoothHFP:
                audioOutput.type = "Bluetooth HFP"
            case .bluetoothLE:
                audioOutput.type = "Bluetooth LE"
            case .builtInMic:
                audioOutput.type = "Built-in Mic"
            case .builtInReceiver:
                audioOutput.type = "Built-in Receiver"
            case .builtInSpeaker:
                audioOutput.type = "Built-in Speaker"
            case .carAudio:
                // Car Audio is always CarPlay https://bignerdranch.com/blog/detecting-caraudio/
                audioOutput.type = "CarPlay"
            case .HDMI:
                audioOutput.type = "HDMI"
            case .headphones:
                audioOutput.type = "Headphones"
            case .headsetMic:
                audioOutput.type = "Headset Mic"
            case .lineIn:
                audioOutput.type = "Line In"
            case .lineOut:
                audioOutput.type = "Line Out"
            case .usbAudio:
                audioOutput.type = "Usb Audio"
            default:
                audioOutput.type = "Unknown"
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
