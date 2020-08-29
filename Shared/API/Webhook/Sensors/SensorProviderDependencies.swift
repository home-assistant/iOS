import Foundation

public protocol SensorProviderUpdateSignaler: AnyObject {
    init(signal: @escaping () -> Void)
}

public class SensorProviderDependencies {
    internal var updateSignalHandler: (SensorProvider.Type) -> Void = { _ in }
    private var updateSignalers: [String: [SensorProviderUpdateSignaler]] = [:]

    public func updateSignaler<SignalerType: SensorProviderUpdateSignaler>(
        for sensorProvider: SensorProvider
    ) -> SignalerType {
        let key = String(describing: type(of: sensorProvider))

        if let existingValue = updateSignalers[key]?.compactMap({ $0 as? SignalerType }).first {
            return existingValue
        }

        let sensorType = type(of: sensorProvider)
        let created = SignalerType.init(signal: { [weak self] in
            self?.updateSignalHandler(sensorType)
        })

        updateSignalers[key, default: []] += [created]
        return created
    }
}
