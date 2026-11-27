import Foundation

struct WebRTCRemoteCandidateStaging {
    enum Decision: Equatable {
        case add
        case hold
        case drop
    }

    var holdsPrivateHosts = true
    private var seen = Set<String>()

    mutating func decision(for sdp: String, sdpMid: String?, sdpMLineIndex: Int32) -> Decision {
        let fields = sdp.split(separator: " ")
        guard fields.count >= 8, fields[6] == "typ" else { return .add }
        let address = fields[4].lowercased()
        let mediaLine = "\(sdpMid ?? "") \(sdpMLineIndex)"
        let key = [mediaLine, String(fields[1]), fields[2].lowercased(), address, String(fields[5]), String(fields[7])]
            .joined(separator: " ")
        guard seen.insert(key).inserted else { return .drop }
        return holdsPrivateHosts && fields[7] == "host" && Self.isPrivate(address) ? .hold : .add
    }

    static func isPrivate(_ address: String) -> Bool {
        if address.hasSuffix(".local") || address == "::1" {
            return true
        }
        if address.contains(":") {
            let prefix = address.split(separator: ":").first.flatMap { UInt16($0, radix: 16) } ?? 0
            return prefix & 0xFE00 == 0xFC00 || prefix & 0xFFC0 == 0xFE80
        }
        let octets = address.split(separator: ".").compactMap { UInt8($0) }
        guard octets.count == 4 else { return false }
        switch (octets[0], octets[1]) {
        case (10, _), (127, _), (192, 168), (169, 254), (172, 16 ... 31):
            return true
        default:
            return false
        }
    }
}
