import Foundation

public class LocalizedManager {
    private let bundle: Bundle
    private var stringProviders = [(StringProviderRequest) -> String?]()

    init() {
        bundle = Bundle(for: Self.self)
    }

    public struct StringProviderRequest {
        public var key: String
        public var table: String
    }
    public func add(stringProvider: @escaping (StringProviderRequest) -> String?) {
        stringProviders.insert(stringProvider, at: 0)
    }

    public func string(_ key: String, _ table: String) -> String {
        let request = StringProviderRequest(key: key, table: table)
        let override = stringProviders.lazy.compactMap { $0(request) }.first

        if let override = override {
            return override
        } else {
            return bundle.localizedString(forKey: key, value: nil, table: table)
        }
    }
}
