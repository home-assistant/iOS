import Foundation

/// Splitting a message too large for one Noise transport message into type `1` fragments.
enum SendspinFragmentation {
    /// Noise caps a transport message at 65535 bytes, 16 of which are the AEAD tag.
    static let maximumPlaintext = 65535 - SendspinNoiseCipherState.tagLength

    static let firstFlag: UInt8 = 0x02
    static let lastFlag: UInt8 = 0x01
    static let reservedFlags: UInt8 = 0xFC

    /// The plaintexts to encrypt and send, in order: the message itself when it fits, otherwise
    /// `[1][flags][orig_type][data]` followed by `[1][flags][data]` fragments.
    static func plaintexts(for message: Data) -> [Data] {
        guard message.count > maximumPlaintext, let originalType = message.first else { return [message] }
        var body = message.dropFirst()
        var fragments: [Data] = []
        var isFirst = true
        while !body.isEmpty || isFirst {
            let header: Data = isFirst ? Data([SendspinBinaryType.fragment, 0, originalType]) : Data([
                SendspinBinaryType.fragment,
                0,
            ])
            let take = min(body.count, maximumPlaintext - header.count)
            let chunk = body.prefix(take)
            body = body.dropFirst(take)
            var flags: UInt8 = isFirst ? firstFlag : 0
            if body.isEmpty {
                flags |= lastFlag
            }
            var fragment = header
            fragment[1] = flags
            fragment.append(contentsOf: chunk)
            fragments.append(fragment)
            isFirst = false
        }
        return fragments
    }
}
