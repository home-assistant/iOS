//
//  InternetAddress.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 5/4/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation

// From https://github.com/lyft/Kronos/blob/fd57b4f7d77ee17c73e12fbdf333627ff7a01f83/Sources/InternetAddress.swift
/// This enum represents an internet address that can either be IPv4 or IPv6.
///
/// - IPv6: An Internet Address of type IPv6 (e.g.: '::1').
/// - IPv4: An Internet Address of type IPv4 (e.g.: '127.0.0.1').
enum InternetAddress: Hashable {
    case ipv6(sockaddr_in6)
    case ipv4(sockaddr_in)

    /// Human readable host represetnation (e.g. '192.168.1.1' or 'ab:ab:ab:ab:ab:ab:ab:ab').
    var host: String? {
        switch self {
        case .ipv6(var address):
            var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            inet_ntop(AF_INET6, &address.sin6_addr, &buffer, socklen_t(INET6_ADDRSTRLEN))
            return String(cString: buffer)

        case .ipv4(var address):
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET, &address.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN))
            return String(cString: buffer)
        }
    }

    /// The protocol family that should be used on the socket creation for this address.
    var family: Int32 {
        switch self {
        case .ipv4:
            return PF_INET

        case .ipv6:
            return PF_INET6
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.host)
    }

    init?(storage: UnsafePointer<sockaddr_storage>) {

        switch Int32(storage.pointee.ss_family) {
        case AF_INET:
            self = storage.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { address in
                InternetAddress.ipv4(address.pointee)
            }

        case AF_INET6:
            self = storage.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { address in
                InternetAddress.ipv6(address.pointee)
            }
        default:
            return nil
        }
    }

    init?(data: Data) {
        if let addr = data.withUnsafeBytes({ rawPointer -> InternetAddress? in
            let pointer = rawPointer.bindMemory(to: sockaddr_storage.self).baseAddress
            return InternetAddress(storage: pointer!)
        }) { self = addr } else { return nil }
    }

    /// Returns the address struct (either sockaddr_in or sockaddr_in6) represented as an CFData.
    ///
    /// - parameter port: The port number to associate on the address struct.
    ///
    /// - returns: An address struct wrapped into a CFData type.
    func addressData(withPort port: Int) -> CFData {
        switch self {
        case .ipv6(var address):
            address.sin6_port = in_port_t(port).bigEndian
            return Data(bytes: &address, count: MemoryLayout<sockaddr_in6>.size) as CFData

        case .ipv4(var address):
            address.sin_port = in_port_t(port).bigEndian
            return Data(bytes: &address, count: MemoryLayout<sockaddr_in>.size) as CFData
        }
    }

    /// Returns true if address is within private network ranges
    /// e.g. 10.0.0.0-10.255.255.255, 172.16.0.0- 172.31.255.255, 192.168.0.0-192.168.255.255
    var isPrivateNetwork: Bool {
        guard let host = self.host else { return false }
        // swiftlint:disable:next line_length
        let pattern = "(^127\\.)|(^192\\.168\\.)|(^10\\.)|(^172\\.1[6-9]\\.)|(^172\\.2[0-9]\\.)|(^172\\.3[0-1]\\.)|(^::1$)|(^[fF][cCdD])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return false }
        return regex.matches(in: host, options: [], range: NSRange(host.startIndex..<host.endIndex, in: host)).count > 0
    }
}

/// Compare InternetAddress(es) by making sure the host representation are equal.
func == (lhs: InternetAddress, rhs: InternetAddress) -> Bool {
    return lhs.host == rhs.host
}
