import Foundation

public class LocalPushStateSync: UserDefaultsValueSync<LocalPushManager.State> {
    public static let settingsKey = "LocalPushSettingsKey"
}

public class UserDefaultsValueSync<ValueType: Codable>: NSObject {
    public let settingsKey: String
    public init(settingsKey: String) {
        self.settingsKey = settingsKey
        super.init()
        Current.settingsStore.prefs.addObserver(
            self,
            forKeyPath: settingsKey,
            options: [.initial],
            context: nil
        )
    }

    public var value: ValueType? {
        set {
            do {
                if let state = newValue {
                    let json = try JSONEncoder().encode(state)
                    Current.settingsStore.prefs.set(json, forKey: settingsKey)
                } else {
                    Current.settingsStore.prefs.removeObject(forKey: settingsKey)
                }
            } catch {
                Current.Log.error("failed to encode: \(error)")
            }
        }
        get {
            guard let data = Current.settingsStore.prefs.data(forKey: settingsKey) else {
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

    private var observers = [(ValueType) -> Void]()
    public func observe(_ handler: @escaping (ValueType) -> Void) {
        observers.append(handler)
    }

    // swiftlint:disable:next block_based_kvo
    override public func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard let value = value else { return }

        for observer in observers {
            observer(value)
        }
    }
}
