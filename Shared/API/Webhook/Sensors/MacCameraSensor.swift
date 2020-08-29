import Foundation
import PromiseKit
#if canImport(CoreMediaIO)
import AVFoundation
import CoreMediaIO
#endif

private class CameraUpdateSignaler: SensorProviderUpdateSignaler {
    let signal: () -> Void

    #if canImport(CoreMediaIO)
    private var observedObjects = Set<CMIOObjectID>()
    #endif

    required init(signal: @escaping () -> Void) {
        self.signal = signal

        #if canImport(CoreMediaIO)
        addObserver(for: CMIOObjectID(kCMIOObjectSystemObject), address: .allDevices)
        #endif
    }

    #if canImport(CoreMediaIO)
    func addObserver<PropertyType>(
        for object: CMIOObjectID,
        address: HACoreMediaProperty<PropertyType>
    ) {
        guard !observedObjects.contains(object) else { return }

        let observedStatus = withUnsafePointer(to: address.address) { ptr in
            OSStatus(CMIOObjectAddPropertyListenerBlock(object, ptr, .main, { [weak self] _, _ in
                Current.Log.info("camera info updated for \(object)")
                self?.signal()
            }))
        }

        Current.Log.info("added observer for \(object): \(observedStatus)")
        observedObjects.insert(object)
    }
    #endif
}

public class MacCameraSensor: SensorProvider {
    public enum MacCameraError: Error, Equatable {
        case noCameras
    }

    public let request: SensorProviderRequest

    #if canImport(CoreMediaIO)
    let systemObject: HACoreMediaObjectSystem

    required public init(request: SensorProviderRequest) {
        self.request = request
        self.systemObject = HACoreMediaObjectSystem()
    }

    public func sensors() -> Promise<[WebhookSensor]> {
        let updateSignaler: CameraUpdateSignaler = request.dependencies.updateSignaler(for: self)

        return firstly {
            Promise<Void>.value(())
        }.map(on: .global(qos: .userInitiated)) { [systemObject] () -> [HACoreMediaObjectCamera] in
            systemObject.allCameras
        }.mapValues { (camera: HACoreMediaObjectCamera) -> WebhookSensor in
            let sensor = Self.sensor(camera: camera)
            updateSignaler.addObserver(for: camera.id, address: .isRunningSomewhere)
            return sensor
        }.recover { (error) -> Promise<[WebhookSensor]> in
            if case PMKError.compactMap = error {
                throw MacCameraError.noCameras
            } else {
                throw error
            }
        }
    }

    private static func sensor(camera: HACoreMediaObjectCamera) -> WebhookSensor {
        let sensor = WebhookSensor(
            name: camera.name ?? "Unknown Camera",
            uniqueID: "camera_\(camera.deviceUID)",
            icon: camera.isOn ? "mdi:camera" : "mdi:camera-off",
            state: camera.isOn
        )

        sensor.Type = "binary_sensor"
        sensor.Attributes = [
            "Manufacturer": camera.manufacturer ?? "Unknown"
        ]

        return sensor
    }

    #else
    required public init(request: SensorProviderRequest) {
        self.request = request
    }

    public func sensors() -> Promise<[WebhookSensor]> {
        return .init(error: MacCameraError.noCameras)
    }
    #endif
}
