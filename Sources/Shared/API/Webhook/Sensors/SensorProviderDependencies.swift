import Foundation

public protocol SensorProviderUpdateSignaler: AnyObject {
    init(signal: @escaping () -> Void)
}

public class SensorProviderDependencies {
    internal var updateSignalHandler: (SensorProvider.Type) -> Void = { _ in }
    private var updateSignalers: [String: [SensorProviderUpdateSignaler]] = [:]

    private func key(for sensorProvider: SensorProvider) -> String {
        String(describing: type(of: sensorProvider))
    }

    internal func existingSignaler<SignalerType: SensorProviderUpdateSignaler>(
        for sensorProvider: SensorProvider
    ) -> SignalerType? {
        let key = self.key(for: sensorProvider)
        return updateSignalers[key]?.compactMap({ $0 as? SignalerType }).first
    }

    public func updateSignaler<SignalerType: SensorProviderUpdateSignaler>(
        for sensorProvider: SensorProvider
    ) -> SignalerType {
        if let existing: SignalerType = existingSignaler(for: sensorProvider) {
            return existing
        }

        let sensorType = type(of: sensorProvider)
        let created = SignalerType(signal: { [weak self] in
            self?.updateSignalHandler(sensorType)
        })

        updateSignalers[key(for: sensorProvider), default: []] += [created]
        return created
    }
}
