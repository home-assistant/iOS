import Foundation

/// Reads the address of a network interface straight from the system, which needs no entitlement or
/// permission (unlike the SSID, which is gated behind location access).
enum NetworkInterfaceAddress {
    /// The IPv4 address assigned to the named interface, if the interface is up and has one.
    ///
    /// `en0` is the Wi-Fi interface on iPhone and iPad.
    static func ipv4(ofInterface name: String) -> String? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else { return nil }
        defer { freeifaddrs(interfaces) }

        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = entry.pointee
            guard String(cString: interface.ifa_name) == name,
                  interface.ifa_flags & UInt32(IFF_UP) != 0,
                  let address = interface.ifa_addr,
                  address.pointee.sa_family == sa_family_t(AF_INET) else {
                continue
            }

            let ipv4 = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
            return format(ipv4)
        }

        return nil
    }

    /// Dotted-decimal notation of an IPv4 address, such as `192.168.178.27`.
    static func format(_ address: in_addr) -> String {
        // `s_addr` is stored in network byte order.
        let value = UInt32(bigEndian: address.s_addr)
        return [24, 16, 8, 0].map { String((value >> $0) & 0xFF) }.joined(separator: ".")
    }
}
