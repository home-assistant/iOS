import Foundation
import HAKit

public class LocalPushStateSync: UserDefaultsValueSync<LocalPushManager.State> {
    public static let settingsKey = "LocalPushSettingsKey"
}

public class UserDefaultsValueSync<ValueType: Codable>: NSObject {
    public let settingsKey: String
    public let userDefaults: UserDefaults

    public init(settingsKey: String, userDefaults: UserDefaults? = nil) {
        self.settingsKey = settingsKey
        self.userDefaults = userDefaults ?? Current.settingsStore.prefs
        super.init()
        self.userDefaults.addObserver(
            self,
            forKeyPath: settingsKey,
            options: [],
            context: nil
        )
    }

    deinit {
        userDefaults.removeObserver(self, forKeyPath: settingsKey)
    }

    public var value: ValueType? {
        set {
            do {
                if let state = newValue {
                    let json = try JSONEncoder().encode(state)
                    userDefaults.set(json, forKey: settingsKey)
                } else {
                    userDefaults.removeObject(forKey: settingsKey)
                }
            } catch {
                Current.Log.error("failed to encode: \(error)")
            }
        }
        get {
            guard let data = userDefaults.data(forKey: settingsKey) else {
                return nil
            }

            do {
                let value = try JSONDecoder().decode(ValueType.self, from: data)
                return value
            } catch {
                Current.Log.error("failed to decode: \(error)")
                return nil
            }
        }
    }

    private var observers = [(identifier: UUID, handler: (ValueType) -> Void)]()
    public func observe(_ handler: @escaping (ValueType) -> Void) -> HACancellable {
        let identifier = UUID()
        observers.append((identifier: identifier, handler: handler))
        return HABlockCancellable { [weak self] in
            self?.observers.removeAll(where: { $0.identifier == identifier })
        }
    }

    // swiftlint:disable:next block_based_kvo
    override public func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard let value = value else { return }

        for observer in observers {
            observer.handler(value)
        }
    }
}
