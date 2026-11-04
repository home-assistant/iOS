import Foundation

/// Rewrites a URL the watch resolved so it points at whichever base the *phone* would use right now.
///
/// This is what makes relaying worth doing. The watch has no network information of its own, so
/// `ConnectionInfo` on the watch can never satisfy the internal-URL check and always lands on a
/// remote URL. When the watch is routing through the phone, its packets leave from the phone's
/// network anyway — so the remote URL is both unnecessary and, on a router without NAT loopback,
/// unreachable. Re-basing onto the phone's active URL puts the request on the URL the phone itself
/// would have used, which is the one that matches where the packets actually come out.
///
/// Only bases the server has configured are recognised, so a URL the watch built from something
/// else is passed through untouched.
public enum WatchRelayURLRebase {
    /// The server's configured bases, in the order a longest-match walk should consider them.
    ///
    /// Deliberately excludes the cloudhook URL: it is an opaque endpoint on Nabu Casa rather than a
    /// base the rest of the API hangs off, so its path can't be transplanted onto another base. It
    /// also already works from any network, which is why `WatchWebhookClient` reaches for it in the
    /// first place — leaving it alone costs nothing.
    static func configuredBases(of connection: ConnectionInfo) -> [URL] {
        [ConnectionInfo.URLType.internal, .external, .remoteUI]
            .compactMap { connection.address(for: $0)?.sanitized() }
            // Longest first: an internal URL that is a prefix of an external one (same host,
            // different path) must not win the match over the more specific base.
            .sorted { $0.absoluteString.count > $1.absoluteString.count }
    }

    /// Whether the phone may dial `url` on the watch's behalf at all.
    ///
    /// A relayed request is forwarded with the headers the watch set, which for most of them
    /// includes its bearer token. So the phone must not send one just anywhere: a malformed or
    /// tampered-with message naming a server the phone does know would otherwise turn it into an
    /// authenticated request to a host of the sender's choosing. Only URLs built on one of the
    /// server's own bases pass, plus the cloudhook host.
    ///
    /// The cloudhook is matched by host rather than exactly, because the URL the watch sends is
    /// from *its* registration while the phone only holds its own — different paths on the same
    /// Nabu Casa host. Those requests carry no bearer token (see `WatchWebhookClient`), so the
    /// looser match costs nothing.
    public static func isPermitted(_ url: URL, connection: ConnectionInfo) -> Bool {
        if let cloudhookHost = connection.cloudhookURL?.host?.lowercased(),
           url.host?.lowercased() == cloudhookHost {
            return true
        }
        return configuredBases(of: connection).contains { base in
            isBase(base.absoluteString, of: url.absoluteString)
        }
    }

    /// `url` with its base swapped for `activeURL`, or `nil` when `url` isn't built on one of
    /// `connection`'s bases (nothing to rebase) or is already on `activeURL` (nothing to change).
    public static func rebased(_ url: URL, connection: ConnectionInfo, activeURL: URL) -> URL? {
        let target = activeURL.sanitized().absoluteString
        let absolute = url.absoluteString

        guard let base = configuredBases(of: connection).first(where: { candidate in
            isBase(candidate.absoluteString, of: absolute)
        }) else {
            return nil
        }

        guard base.absoluteString != target else { return nil }

        let suffix = String(absolute.dropFirst(base.absoluteString.count))
        return URL(string: target + suffix)
    }

    /// Whether `base` is a path-boundary prefix of `absolute`. A bare string prefix would match
    /// `https://ha.local` against `https://ha.local.evil.com`, so the character that follows the
    /// base has to start a path, query or fragment — or the URL has to be the base exactly.
    private static func isBase(_ base: String, of absolute: String) -> Bool {
        guard absolute.hasPrefix(base) else { return false }
        guard absolute.count > base.count else { return true }
        let next = absolute[absolute.index(absolute.startIndex, offsetBy: base.count)]
        return next == "/" || next == "?" || next == "#"
    }
}
