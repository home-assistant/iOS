import Foundation
import HAKit

public protocol SensorProviderUpdateSignaler: AnyObject {
    init(signal: @escaping () -> Void)
}

public class SensorProviderDependencies {
    var updateSignalHandler: (SensorProvider.Type) -> Void = { _ in }
    private let updateSignalers = HAProtected<[String: [SensorProviderUpdateSignaler]]>(value: [:])

    private func key(for sensorProvider: SensorProvider) -> String {
        String(describing: type(of: sensorProvider))
    }

    func existingSignaler<SignalerType: SensorProviderUpdateSignaler>(
        for sensorProvider: SensorProvider
    ) -> SignalerType? {
        let key = key(for: sensorProvider)
        return updateSignalers.read { $0[key]?.compactMap { $0 as? SignalerType }.first }
    }

    public func updateSignaler<SignalerType: SensorProviderUpdateSignaler>(
        for sensorProvider: SensorProvider
    ) -> SignalerType {
        if let existing: SignalerType = existingSignaler(for: sensorProvider) {
            return existing
        }

        let key = key(for: sensorProvider)
        let sensorType = type(of: sensorProvider)
        let created = SignalerType(signal: { [weak self] in
            self?.updateSignalHandler(sensorType)
        })

        return updateSignalers.mutate { signalers in
            if let existing = signalers[key]?.compactMap({ $0 as? SignalerType }).first {
                return existing
            }
            signalers[key, default: []].append(created)
            return created
        }
    }
}
