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
        addCoreMediaObserver(for: CMIOObjectID(kCMIOObjectSystemObject), property: .allDevices)
        #endif

        #if targetEnvironment(macCatalyst)
        addCoreAudioObserver(for: AudioObjectID(kAudioObjectSystemObject), property: .allDevices)
        #endif
    }

    private func addObserver<PropertyType: HACoreBlahProperty>(object: ObservedObjectType, property: PropertyType) {
        guard !observedObjects.contains(object) else { return }

        let observedStatus = property.addListener(objectID: object.id) { [weak self] in
            Current.Log.info("info updated for \(object)")
            self?.signal()
        }

        Current.Log.info("added observer for \(object): \(observedStatus)")
        observedObjects.insert(object)
    }

    // object IDs both alias to UInt32 so we can't rely on the type system to know which method to call

    #if targetEnvironment(macCatalyst)
    func addCoreAudioObserver<PropertyType>(
        for id: AudioObjectID,
        property: HACoreAudioProperty<PropertyType>
    ) {
        addObserver(object: .coreAudio(id), property: property)
    }
    #endif

    #if canImport(CoreMediaIO)
    func addCoreMediaObserver<PropertyType>(
        for id: CMIOObjectID,
        property: HACoreMediaProperty<PropertyType>
    ) {
        addObserver(object: .coreMedia(id), property: property)
    }
    #endif
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
            updateSignaler.addCoreMediaObserver(for: camera.id, property: .isRunningSomewhere)
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
            updateSignaler.addCoreAudioObserver(for: microphone.id, property: .isRunningSomewhere)
            return Self.sensor(microphone: microphone)
        }
        #else
        microphones = .value([])
        #endif

        return when(fulfilled: [ cameras, microphones ])
            .map { $0.flatMap { $0 } }
            .get { sensors in
                if sensors.isEmpty {
                    throw InputDeviceError.noInputs
                }
            }
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
