import Foundation
import PromiseKit
#if canImport(CoreMediaIO)
import AVFoundation
import CoreMediaIO
#endif
#if targetEnvironment(macCatalyst)
import CoreAudio
#endif

private class InputOutputDeviceUpdateSignaler: BaseSensorUpdateSignaler, SensorProviderUpdateSignaler {
    let signal: () -> Void

    enum ObservedObjectType: Hashable {
        // so iOS (which has neither CoreMediaIO nor the CoreAudio APIs we need) doesn't whine about empty enum
        case invalid

        #if targetEnvironment(macCatalyst)
        // Carries the property selector as well as the object, because the system object is observed
        // for more than one property and the two registrations must not collapse into one.
        case coreAudio(AudioObjectID, AudioObjectPropertySelector)
        #if canImport(CoreMediaIO)
        case coreMedia(CMIOObjectID)
        #endif
        #endif

        var id: UInt32 {
            switch self {
            case .invalid: return .max
            #if targetEnvironment(macCatalyst)
            case let .coreAudio(id, _): return id
            #if canImport(CoreMediaIO)
            case let .coreMedia(id): return id
            #endif
            #endif
            }
        }
    }

    private var observedObjects = Set<ObservedObjectType>()

    required init(signal: @escaping () -> Void) {
        self.signal = signal
        super.init(relatedSensorsIds: [
            .iPhoneAudioOutput,
            .camera,
            .microphone,
            .audioOutput,
        ])
    }

    private func addObserver(object: ObservedObjectType, property: some HACoreBlahProperty) {
        guard !observedObjects.contains(object) else { return }

        let observedStatus = property.addListener(objectID: object.id) { [weak self] in
            Current.Log.info("info updated for \(object)")
            self?.signal()
        }

        Current.Log.info("added observer for \(object): \(observedStatus)")
        observedObjects.insert(object)
    }

    private func removeObserver(object: ObservedObjectType) {
        guard observedObjects.contains(object) else { return }
        observedObjects.remove(object)
    }

    // object IDs both alias to UInt32 so we can't rely on the type system to know which method to call

    #if targetEnvironment(macCatalyst)
    #if canImport(CoreMediaIO)
    func addCoreAudioObserver(
        for id: AudioObjectID,
        property: HACoreAudioProperty<some Any>
    ) {
        addObserver(object: .coreAudio(id, property.address.mSelector), property: property)
    }

    func removeCoreAudioObserver(
        for id: AudioObjectID,
        property: HACoreAudioProperty<some Any>
    ) {
        removeObserver(object: .coreAudio(id, property.address.mSelector))
    }

    func addCoreMediaObserver(
        for id: CMIOObjectID,
        property: HACoreMediaProperty<some Any>
    ) {
        addObserver(object: .coreMedia(id), property: property)
    }

    func removeCoreMediaObserver(
        for id: CMIOObjectID
    ) {
        removeObserver(object: .coreMedia(id))
    }
    #endif
    #endif

    override func observe() {
        super.observe()
        guard !isObserving else { return }
        #if targetEnvironment(macCatalyst)
        #if canImport(CoreMediaIO)
        addCoreMediaObserver(for: CMIOObjectID(kCMIOObjectSystemObject), property: .allDevices)
        #endif

        addCoreAudioObserver(for: AudioObjectID(kAudioObjectSystemObject), property: .allDevices)
        // A device already running in one direction stays running as the other direction starts and
        // stops, so the device flag alone misses that transition. The process object list changes
        // whenever a process starts or stops doing IO, which covers one app recording while another
        // plays back through the same device.
        addCoreAudioObserver(for: AudioObjectID(kAudioObjectSystemObject), property: .processObjectList)
        #endif
        isObserving = true
    }

    override func stopObserving() {
        super.stopObserving()
        guard isObserving else { return }
        #if targetEnvironment(macCatalyst)
        #if canImport(CoreMediaIO)
        removeCoreMediaObserver(for: CMIOObjectID(kCMIOObjectSystemObject))
        #endif

        removeCoreAudioObserver(for: AudioObjectID(kAudioObjectSystemObject), property: .allDevices)
        removeCoreAudioObserver(for: AudioObjectID(kAudioObjectSystemObject), property: .processObjectList)
        #endif
        isObserving = false
    }
}

public class InputOutputDeviceSensor: SensorProvider {
    public enum InputOutputDeviceError: Error, Equatable {
        case noInputsOrOutputs
    }

    public let request: SensorProviderRequest

    #if targetEnvironment(macCatalyst)
    #if canImport(CoreMediaIO)
    let cameraSystemObject: HACoreMediaObjectSystem
    #endif
    let audioSystemObject: HACoreAudioObjectSystem
    #endif

    public required init(request: SensorProviderRequest) {
        self.request = request
        #if targetEnvironment(macCatalyst)
        #if canImport(CoreMediaIO)
        self.cameraSystemObject = HACoreMediaObjectSystem()
        #endif
        self.audioSystemObject = HACoreAudioObjectSystem()
        #endif
    }

    public func sensors() -> Promise<[WebhookSensor]> {
        let updateSignaler: InputOutputDeviceUpdateSignaler = request.dependencies.updateSignaler(for: self)

        let sensors: Promise<[WebhookSensor]>

        #if canImport(CoreMediaIO) && targetEnvironment(macCatalyst)
        let queue: DispatchQueue = .global(qos: .userInitiated)
        sensors = firstly {
            Promise<Void>.value(())
        }.map(on: queue) { [cameraSystemObject, audioSystemObject] in
            (cameraSystemObject.allCameras, audioSystemObject.allInputDevices, audioSystemObject.allOutputDevices)
        }.get(on: queue) { cameras, audioInputs, audioOutputs in
            cameras.forEach { updateSignaler.addCoreMediaObserver(for: $0.id, property: .isRunningSomewhere) }
            // kAudioDevicePropertyDeviceIsRunningSomewhere is only ever published in the global scope, so a
            // listener scoped to input or output registers happily and then never fires. A device that both
            // records and plays back needs a single listener here, and the direction sorted out on read.
            for device in audioInputs + audioOutputs {
                updateSignaler.addCoreAudioObserver(for: device.id, property: .isRunningSomewhere)
            }
        }.map(on: queue) { [audioSystemObject] cameras, audioInputs, audioOutputs -> [WebhookSensor] in
            Self.sensors(
                cameras: cameras,
                audioInputs: audioInputs,
                audioOutputs: audioOutputs,
                runningDevices: audioSystemObject.runningDevices
            )
        }
        #else
        sensors = .init(error: InputOutputDeviceError.noInputsOrOutputs)
        #endif

        return sensors
    }

    #if canImport(CoreMediaIO) && targetEnvironment(macCatalyst)
    private static func sensors(
        cameras: [HACoreMediaObjectCamera],
        audioInputs: [HACoreAudioObjectDevice],
        audioOutputs: [HACoreAudioObjectDevice],
        runningDevices: HACoreAudioRunningDevices?
    ) -> [WebhookSensor] {
        let cameraFallback = "Unknown Camera"
        let audioInputFallback = "Unknown Audio Input"
        let audioOutputFallback = "Unknown Audio Output"

        let activeAudioInputs = audioInputs.filter { $0.isInputOn(runningDevices: runningDevices) }
        let activeAudioOutputs = audioOutputs.filter { $0.isOutputOn(runningDevices: runningDevices) }

        return Self.sensors(
            name: "Camera",
            uniqueID: WebhookSensorId.camera.rawValue,
            iconOn: "mdi:camera",
            iconOff: "mdi:camera-off",
            all: cameras.map { $0.name ?? cameraFallback },
            active: cameras.filter(\.isOn).map { $0.name ?? cameraFallback }
        ) + Self.sensors(
            name: "Audio Input",
            uniqueID: WebhookSensorId.microphone.rawValue,
            iconOn: "mdi:microphone",
            iconOff: "mdi:microphone-off",
            all: audioInputs.map { $0.name ?? audioInputFallback },
            active: activeAudioInputs.map { $0.name ?? audioInputFallback }
        ) + Self.sensors(
            name: "Audio Output",
            uniqueID: WebhookSensorId.audioOutput.rawValue,
            iconOn: "mdi:volume-high",
            iconOff: "mdi:volume-low",
            all: audioOutputs.map { $0.name ?? audioOutputFallback },
            active: activeAudioOutputs.map { $0.name ?? audioOutputFallback }
        )
    }

    private static func sensors(
        name: String,
        uniqueID: String,
        iconOn: String,
        iconOff: String,
        all: [String],
        active: [String]
    ) -> [WebhookSensor] {
        let anyActive = active.isEmpty == false

        return [
            with(WebhookSensor(
                name: "\(name) In Use",
                uniqueID: "\(uniqueID)_in_use",
                icon: anyActive ? iconOn : iconOff,
                state: anyActive
            )) {
                $0.Type = "binary_sensor"
            },
            with(WebhookSensor(
                name: "Active \(name)",
                uniqueID: "active_\(uniqueID)",
                icon: anyActive ? iconOn : iconOff,
                state: active.first ?? "Inactive"
            )) {
                $0.Attributes = [
                    "All \(name)": all,
                    "Active \(name)": active,
                ]
            },
        ]
    }
    #endif
}
