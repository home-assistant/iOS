import Foundation

public extension HAWatchConnectivity {
    /// A complication update transfer (backed by `transferCurrentComplicationUserInfo` on iOS). Its
    /// envelope is `["__complication_info__": content]`, matching the pod's wire format.
    struct ComplicationInfo {
        public let content: Content

        public init(content: Content = [:]) {
            self.content = content
        }

        init?(jsonDictionary: Content) {
            guard let payload = jsonDictionary[PayloadKey.complicationInfo] as? Content else {
                return nil
            }
            self.content = payload
        }

        func jsonRepresentation() -> Content {
            [PayloadKey.complicationInfo: content]
        }
    }
}
