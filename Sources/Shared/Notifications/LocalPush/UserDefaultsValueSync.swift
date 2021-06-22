import Foundation
import HAKit

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

    deinit {
        Current.settingsStore.prefs.removeObserver(self, forKeyPath: settingsKey)
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
