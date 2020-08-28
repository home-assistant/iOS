import Foundation

public protocol SensorProviderLiveUpdateInfo: AnyObject {
    init(notifying: @escaping () -> Void)
}

public class SensorProviderDependencies {
    var liveUpdateHandler: (SensorProvider.Type) -> Void = { _ in }
    private var liveUpdateInfos = [SensorProviderLiveUpdateInfo]()

    func liveUpdateInfo<InfoType: SensorProviderLiveUpdateInfo>(
        for sensorProvider: SensorProvider
    ) -> InfoType {
        if let existing = liveUpdateInfos.compactMap({ $0 as? InfoType }).first {
            return existing
        }

        let sensorType = type(of: sensorProvider)
        let created = InfoType.init(notifying: { [weak self] in
            self?.liveUpdateHandler(sensorType)
        })
        liveUpdateInfos.append(created)
        return created
    }
}
