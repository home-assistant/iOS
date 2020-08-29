import Foundation

public protocol SensorProviderLiveUpdateInfo: AnyObject {
    init(notifying: @escaping () -> Void)
}

public class SensorProviderDependencies {
    internal var liveUpdateHandler: (SensorProvider.Type) -> Void = { _ in }
    private var liveUpdateInfos = [
        String: [SensorProviderLiveUpdateInfo]
    ]()

    public func liveUpdateInfo<InfoType: SensorProviderLiveUpdateInfo>(
        for sensorProvider: SensorProvider
    ) -> InfoType {
        let key = String(describing: type(of: sensorProvider))

        if let existingValue = liveUpdateInfos[key]?.compactMap({ $0 as? InfoType }).first {
            return existingValue
        }

        let sensorType = type(of: sensorProvider)
        let created = InfoType.init(notifying: { [weak self] in
            self?.liveUpdateHandler(sensorType)
        })

        liveUpdateInfos[key, default: []] += [created]
        return created
    }
}
