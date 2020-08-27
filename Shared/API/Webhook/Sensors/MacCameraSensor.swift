import Foundation
import PromiseKit
#if targetEnvironment(macCatalyst)
import AVFoundation
import CoreMediaIO
#endif

public class MacCameraSensor: SensorProvider {
    public enum MacCameraError: Error, Equatable {
        case noCameras
    }

    public let request: SensorProviderRequest
    required public init(request: SensorProviderRequest) {
        self.request = request
    }

    #if targetEnvironment(macCatalyst)
    public func sensors() -> Promise<[WebhookSensor]> {
        firstly {
            Promise<Void>.value(())
        }.map(on: .global(qos: .userInitiated)) {
            let cams = self.cameras
            if cams.count == 0 {
                throw MacCameraError.noCameras
            }
            return try cams.compactMap { try Self.sensor(camera: $0) }
        }
    }

    private static func sensor(camera: Camera) throws -> WebhookSensor {
        let sensor = WebhookSensor(
            name: camera.name ?? "Unknown Camera",
            uniqueID: "camera_\(camera.id)",
            icon: camera.isOn ? .cameraIcon : .cameraOffIcon,
            state: camera.isOn
        )

        sensor.Attributes = [
            "Manufacturer": camera.manufacturer ?? "Unknown"
        ]

        return sensor
    }

    var cameras: [Camera] {
        var innerArray: [Camera] = []
        var opa = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster)
        )

        var dataSize: UInt32 = 0
        var dataUsed: UInt32 = 0
        var result = CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &opa, 0, nil, &dataSize)
        var devices: UnsafeMutableRawPointer?

        repeat {
            if devices != nil {
                free(devices)
                devices = nil
            }

            devices = malloc(Int(dataSize))
            result = CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &opa, 0, nil, dataSize, &dataUsed,
                                               devices)
        } while result == OSStatus(kCMIOHardwareBadPropertySizeError)

        if let devices = devices {
            for offset in stride(from: 0, to: dataSize, by: MemoryLayout<CMIOObjectID>.size) {
                let current = devices.advanced(by: Int(offset)).assumingMemoryBound(to: CMIOObjectID.self)
                innerArray.append(Camera(id: current.pointee))
            }
        }

        free(devices)

        return innerArray
    }

    struct Camera {
        var id: CMIOObjectID
        var name: String? {
            var address: CMIOObjectPropertyAddress = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIOObjectPropertyName),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster))

            var name: CFString?
            let propsize: UInt32 = UInt32(MemoryLayout<CFString?>.size)
            var dataUsed: UInt32 = 0

            let result: OSStatus = CMIOObjectGetPropertyData(self.id, &address, 0, nil, propsize, &dataUsed, &name)
            if result != 0 {
                return nil
            }

            return name as String?
        }

        var manufacturer: String? {
            var address: CMIOObjectPropertyAddress = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIOObjectPropertyManufacturer),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMaster))

            var manufName: CFString?
            let propsize: UInt32 = UInt32(MemoryLayout<CFString?>.size)
            var dataUsed: UInt32 = 0

            let result: OSStatus = CMIOObjectGetPropertyData(self.id, &address, 0, nil, propsize, &dataUsed, &manufName)
            if result != 0 {
                return nil
            }

            return manufName as String?
        }

        var isOn: Bool {
            var opa = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
            )

            var isUsed = false

            var dataSize: UInt32 = 0
            var dataUsed: UInt32 = 0
            var result = CMIOObjectGetPropertyDataSize(self.id, &opa, 0, nil, &dataSize)
            if result == OSStatus(kCMIOHardwareNoError) {
                if let data = malloc(Int(dataSize)) {
                    result = CMIOObjectGetPropertyData(self.id, &opa, 0, nil, dataSize, &dataUsed, data)
                    let on = data.assumingMemoryBound(to: UInt8.self)
                    isUsed = on.pointee != 0
                }
            }

            return isUsed
        }
    }

    #else
    public func sensors() -> Promise<[WebhookSensor]> {
        return .init(error: MacCameraError.noCameras)
    }
    #endif
}
