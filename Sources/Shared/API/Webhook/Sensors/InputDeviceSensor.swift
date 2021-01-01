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
            Self.sensors(cameras: cameras, microphones: microphones)
        }
        #else
        sensors = .init(error: InputDeviceError.noInputs)
        #endif

        return sensors
    }

    #if canImport(CoreMediaIO) && targetEnvironment(macCatalyst)
    private static func sensors(
        cameras: [HACoreMediaObjectCamera],
        microphones: [HACoreAudioObjectDevice]
    ) -> [WebhookSensor] {
        let cameraFallback = "Unknown Camera"
        let microphoneFallback = "Unknown Microphone"

        return Self.sensors(
            name: "Camera",
            iconOn: "mdi:camera",
            iconOff: "mdi:camera-off",
            all: cameras.map { $0.name ?? cameraFallback },
            active: cameras.filter(\.isOn).map { $0.name ?? cameraFallback }
        ) + Self.sensors(
            name: "Microphone",
            iconOn: "mdi:microphone",
            iconOff: "mdi:microphone-off",
            all: microphones.map { $0.name ?? microphoneFallback },
            active: microphones.filter(\.isOn).map { $0.name ?? microphoneFallback }
        )
    }

    private static func sensors(
        name: String,
        iconOn: String,
        iconOff: String,
        all: [String],
        active: [String]
    ) -> [WebhookSensor] {
        let anyActive = active.isEmpty == false

        return [
            with(WebhookSensor(
                name: "\(name) In Use",
                uniqueID: "\(name.lowercased())_in_use",
                icon: anyActive ? iconOn : iconOff,
                state: anyActive
            )) {
                $0.Type = "binary_sensor"
            },
            with(WebhookSensor(
                name: "Active \(name)",
                uniqueID: "active_\(name.lowercased())",
                icon: anyActive ? iconOn : iconOff,
                state: active.first ?? "Inactive"
            )) {
                $0.Attributes = [
                    "All \(name)": all,
                    "Active \(name)": active
                ]
            }
        ]
    }
    #endif
}
