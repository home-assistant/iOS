import Foundation

public class LocalizedManager {
    private let bundle: Bundle
    private var stringProviders = [(StringProviderRequest) -> String?]()

    init() {
        self.bundle = Bundle(for: Self.self)

        if let fallbackBundle = bundle.url(forResource: "en", withExtension: "lproj").flatMap(Bundle.init(url:)) {
            add(stringProvider: { request in
                if request.key == request.defaultValue || request.defaultValue == "" {
                    // fall back to the english language version if Localizable.strings is missing this key
                    // this should only happen if we don't pull new strings before cutting a release
                    return fallbackBundle.localizedString(forKey: request.key, value: nil, table: request.table)
                } else {
                    return nil
                }
            })
        }
    }

    public struct StringProviderRequest {
        public var key: String
        public var table: String
        public var defaultValue: String
    }

    public func add(stringProvider: @escaping (StringProviderRequest) -> String?) {
        stringProviders.insert(stringProvider, at: 0)
    }

    public func frontend(_ key: String) -> String? {
        let result = string(key, "Frontend")
        guard result != key else {
            return nil
        }
        return result
    }

    public func string(_ key: String, _ table: String) -> String {
        let defaultValue = bundle.localizedString(forKey: key, value: nil, table: table)
        let request = StringProviderRequest(key: key, table: table, defaultValue: defaultValue)
        let override = stringProviders.lazy.compactMap { $0(request) }.first

        if let override = override {
            return override
        }

        return defaultValue
    }
}
