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

        let sensors: Promise<[WebhookSensor]>

        #if canImport(CoreMediaIO) && targetEnvironment(macCatalyst)
        let queue: DispatchQueue = .global(qos: .userInitiated)
        sensors = firstly {
            Promise<Void>.value(())
        }.map(on: queue) { [cameraSystemObject, audioSystemObject] in
            (cameraSystemObject.allCameras, audioSystemObject.allInputDevices)
        }.get(on: queue) { cameras, microphones in
            cameras.forEach { updateSignaler.addCoreMediaObserver(for: $0.id, property: .isRunningSomewhere) }
            microphones.forEach { updateSignaler.addCoreAudioObserver(for: $0.id, property: .isRunningSomewhere) }
        }.map(on: queue) { cameras, microphones -> [WebhookSensor] in
            let nameSet = NSCountedSet(array: cameras.compactMap(\.name) + microphones.compactMap(\.name))

            return cameras.compactMap { Self.sensor(camera: $0, nameSet: nameSet) }
                + microphones.compactMap { Self.sensor(microphone: $0, nameSet: nameSet) }
        }
        #else
        sensors = .init(error: InputDeviceError.noInputs)
        #endif

        return sensors
    }

    private static func name(given: String?, multiSuffix: String, fallback: String, nameSet: NSCountedSet) -> String {
        if let given = given {
            if nameSet.count(for: given) > 1 {
                // More than 1 item has the same name, add suffix
                return given + multiSuffix
            } else {
                return given
            }
        } else {
            return fallback
        }
    }

    #if canImport(CoreMediaIO)
    private static func sensor(camera: HACoreMediaObjectCamera, nameSet: NSCountedSet) -> WebhookSensor? {
        guard let deviceUID = camera.deviceUID else {
            Current.Log.error("ignoring camera with id \(camera.id) due to not unique ID")
            return nil
        }

        let sensor = WebhookSensor(
            name: Self.name(
                given: camera.name,
                multiSuffix: " (Camera)",
                fallback: "Unknown Camera",
                nameSet: nameSet
            ),
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
    private static func sensor(microphone: HACoreAudioObjectDevice, nameSet: NSCountedSet) -> WebhookSensor? {
        guard let deviceUID = microphone.deviceUID else {
            Current.Log.error("ignoring input with id \(microphone.id) due to not unique ID")
            return nil
        }

        let sensor = WebhookSensor(
            name: Self.name(
                given: microphone.name,
                multiSuffix: " (Microphone)",
                fallback: "Unknown Microphone",
                nameSet: nameSet
            ),
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
