import AVFoundation
import Combine
#if os(macOS)
import CoreAudio
#endif
import Foundation
import HAKit
import Intents
import PromiseKit

#if os(iOS)
final class iOSAudioOutputSensorUpdateSignaler: BaseSensorUpdateSignaler, SensorProviderUpdateSignaler {
    /// Activating or deactivating an audio session (Assist recording, TTS playback, a camera stream)
    /// fires several route changes in a row, and each signal costs a full sensor update, so wait for
    /// the route to settle and send one.
    private static let routeChangeDebounce: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(500)

    private var cancellables: Set<AnyCancellable> = []
    private let signal: () -> Void

    init(signal: @escaping () -> Void) {
        self.signal = signal
        super.init(relatedSensorsIds: [
            .iPhoneAudioOutput,
        ])
    }

    override func observe() {
        super.observe()
        guard !isObserving else { return }
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .debounce(for: Self.routeChangeDebounce, scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.signal()
            }
            .store(in: &cancellables)
        isObserving = true
    }

    override func stopObserving() {
        super.stopObserving()
        guard isObserving else { return }
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        isObserving = false
    }
}
#endif

#if os(macOS)
final class MacAudioOutputSensorUpdateSignaler: BaseSensorUpdateSignaler, SensorProviderUpdateSignaler {
    private let signal: () -> Void

    init(signal: @escaping () -> Void) {
        self.signal = signal
        super.init(relatedSensorsIds: [
            .iPhoneAudioOutput,
        ])
    }

    override func observe() {
        super.observe()
        guard !isObserving else { return }
        let status = HACoreAudioProperty<AudioDeviceID>.defaultOutputDevice.addListener(
            objectID: UInt32(kAudioObjectSystemObject)
        ) { [weak self] in
            self?.signal()
        }
        Current.Log.info("added default output device observer: \(status)")
        isObserving = true
    }
}
#endif

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
        #elseif os(macOS)
        sensors.append(.init(
            name: "Audio Output",
            uniqueID: WebhookSensorId.iPhoneAudioOutput.rawValue,
            icon: "mdi:volume-high",
            state: getDefaultOutput() ?? "unavailable"
        ))
        #endif
        return .value(sensors)
    }

    #if os(macOS)
    private func getDefaultOutput() -> String? {
        let _: MacAudioOutputSensorUpdateSignaler = request.dependencies.updateSignaler(for: self)
        return HACoreAudioObjectSystem().defaultOutputDevice?.transportTypeName
    }
    #endif

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
