import Foundation
import PromiseKit
#if canImport(CoreMediaIO)
import AVFoundation
import CoreMediaIO
#endif
#if targetEnvironment(macCatalyst)
import CoreAudio
#endif

private class InputDeviceUpdateSignaler: SensorProviderUpdateSignaler {
    let signal: () -> Void

    enum ObservedObjectType: Hashable {
        // so iOS (which has neither CoreMediaIO nor the CoreAudio APIs we need) doesn't whine about empty enum
        case invalid

        #if targetEnvironment(macCatalyst)
        case coreAudio(AudioObjectID)
        #endif
        #if canImport(CoreMediaIO)
        case coreMedia(CMIOObjectID)
        #endif

        var id: UInt32 {
            switch self {
            case .invalid: return .max
            #if targetEnvironment(macCatalyst)
            case .coreAudio(let id): return id
            #endif
            #if canImport(CoreMediaIO)
            case .coreMedia(let id): return id
            #endif
            }
        }
    }

    private var observedObjects = Set<ObservedObjectType>()

    required init(signal: @escaping () -> Void) {
        self.signal = signal

        #if canImport(CoreMediaIO)
        addObserver(for: .coreMedia(CMIOObjectID(kCMIOObjectSystemObject)), address: .cmAllDevices)
        #endif

        #if targetEnvironment(macCatalyst)
        addObserver(for: .coreAudio(AudioObjectID(kAudioObjectSystemObject)), address: .caAllDevices)
        #endif
    }

    func addObserver<PropertyType>(
        for object: ObservedObjectType,
        address: HACoreBlahProperty<PropertyType>
    ) {
        guard !observedObjects.contains(object) else { return }

        let observedStatus = address.addListener(objectID: object.id) { [weak self] in
            Current.Log.info("info updated for \(object)")
            self?.signal()
        }

        Current.Log.info("added observer for \(object): \(observedStatus)")
        observedObjects.insert(object)
    }
}

public class InputDeviceSensor: SensorProvider {
    public enum InputDeviceError: Error, Equatable {
        case noInputs
    }

    public let request: SensorProviderRequest

    #if canImport(CoreMediaIO)
    let cameraSystemObject: HACoreMediaObjectSystem
    #endif
    #if targetEnvironment(macCatalyst)
    let audioSystemObject: HACoreAudioObjectSystem
    #endif

    required public init(request: SensorProviderRequest) {
        self.request = request
        #if canImport(CoreMediaIO)
        self.cameraSystemObject = HACoreMediaObjectSystem()
        #endif
        #if targetEnvironment(macCatalyst)
        self.audioSystemObject = HACoreAudioObjectSystem()
        #endif
    }

    public func sensors() -> Promise<[WebhookSensor]> {
        let updateSignaler: InputDeviceUpdateSignaler = request.dependencies.updateSignaler(for: self)

        let cameras: Promise<[WebhookSensor]>

        #if canImport(CoreMediaIO)
        cameras = firstly {
            Promise<Void>.value(())
        }.map(on: .global(qos: .userInitiated)) { [cameraSystemObject] () -> [HACoreMediaObjectCamera] in
            cameraSystemObject.allCameras
        }.compactMapValues { (camera: HACoreMediaObjectCamera) -> WebhookSensor? in
            updateSignaler.addObserver(for: .coreMedia(camera.id), address: .cmIsRunningSomewhere)
            return Self.sensor(camera: camera)
        }
        #else
        cameras = .value([])
        #endif

        let microphones: Promise<[WebhookSensor]>

        #if targetEnvironment(macCatalyst)
        microphones = firstly {
            Promise<Void>.value(())
        }.map(on: .global(qos: .userInitiated)) { [audioSystemObject] () -> [HACoreAudioObjectDevice] in
            audioSystemObject.allDevices.filter(\.isInput)
        }.compactMapValues { (microphone: HACoreAudioObjectDevice) -> WebhookSensor? in
            updateSignaler.addObserver(for: .coreAudio(microphone.id), address: .caIsRunningSomewhere)
            return Self.sensor(microphone: microphone)
        }
        #else
        microphones = .value([])
        #endif

        return when(fulfilled: [ cameras, microphones ])
            .map { $0.flatMap { $0 } }
    }

    #if canImport(CoreMediaIO)
    private static func sensor(camera: HACoreMediaObjectCamera) -> WebhookSensor? {
        guard let deviceUID = camera.deviceUID else {
            Current.Log.error("ignoring camera with id \(camera.id) due to not unique ID")
            return nil
        }

        let sensor = WebhookSensor(
            name: camera.name ?? "Unknown Camera",
            uniqueID: "camera_\(deviceUID)",
            icon: camera.isOn ? "mdi:camera" : "mdi:camera-off",
            state: camera.isOn
        )

        sensor.Type = "binary_sensor"
        sensor.Attributes = [
            "Manufacturer": camera.manufacturer ?? "Unknown"
        ]

        return sensor
    }
    #endif

    #if targetEnvironment(macCatalyst)
    private static func sensor(microphone: HACoreAudioObjectDevice) -> WebhookSensor? {
        guard let deviceUID = microphone.deviceUID else {
            Current.Log.error("ignoring input with id \(microphone.id) due to not unique ID")
            return nil
        }

        let sensor = WebhookSensor(
            name: microphone.name ?? "Unknown Microphone",
            uniqueID: "microphone_\(deviceUID)",
            icon: microphone.isOn ? "mdi:microphone" : "mdi:microphone-off",
            state: microphone.isOn
        )

        sensor.Type = "binary_sensor"
        sensor.Attributes = [
            "Manufacturer": microphone.manufacturer ?? "Unknown"
        ]

        return sensor
    }
    #endif
}
