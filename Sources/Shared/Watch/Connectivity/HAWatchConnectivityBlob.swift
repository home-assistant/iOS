import Foundation

public extension HAWatchConnectivity {
    /// A large-data transfer (backed by `transferFile`). The body is an archived
    /// `["identifier": String, "content": Data]` dictionary, matching the pod's wire format.
    struct Blob {
        public let identifier: String
        public let content: Data
        public let metadata: Content?

        public init(identifier: String, content: Data, metadata: Content? = nil) {
            self.identifier = identifier
            self.content = content
            self.metadata = metadata
        }

        func dataRepresentation() -> Data? {
            let root: [String: Any] = [PayloadKey.identifier: identifier, PayloadKey.content: content]
            return try? NSKeyedArchiver.archivedData(withRootObject: root, requiringSecureCoding: false)
        }

        /// Reconstruct a blob from a received file. MUST be called synchronously inside the delegate's
        /// `didReceive` callback — WatchConnectivity deletes the temp file once the callback returns.
        static func decode(fileURL: URL, metadata: Content?) -> Blob? {
            guard let data = try? Data(contentsOf: fileURL) else {
                return nil
            }
            let classes: [AnyClass] = [
                NSDictionary.self, NSString.self, NSData.self, NSNumber.self, NSArray.self, NSDate.self,
            ]
            guard let root = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: classes, from: data) as? [String: Any],
                  let identifier = root[PayloadKey.identifier] as? String,
                  let content = root[PayloadKey.content] as? Data else {
                return nil
            }
            return Blob(identifier: identifier, content: content, metadata: metadata)
        }
    }
}
