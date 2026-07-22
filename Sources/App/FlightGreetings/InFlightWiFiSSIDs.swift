import Foundation

/// Known onboard Wi-Fi network names offered by airlines. SSIDs and patterns are normalized to
/// lowercase with spaces, hyphens and underscores removed, so "SAS WiFi", "SAS Wi-Fi", "SASWIFI"
/// and "SAS_Wi_Fi" all match the single pattern "saswifi". Matching any entry is treated as a
/// definitive signal that the user is on a plane.
enum InFlightWiFiSSIDs {
    /// Matched as substrings of the normalized SSID, so one entry covers variants like
    /// "DeltaWiFi.com" or "Free Wi-Fi at AlaskaWifi.com".
    private static let patterns: [String] = [
        "aainflight",
        "acwifi",
        "aegean",
        "aerlingus",
        "aeromexico",
        "airasia",
        "airfrance",
        "airnz",
        "alaskawifi",
        "anawifiservice",
        "aviancaonair",
        "azulplay",
        "bastarlink",
        "bawifi",
        "cathaypacific",
        "copaintranet",
        "copashowpass",
        "deltawifi",
        "egyptair",
        "etihad",
        "eurowings",
        "finnair",
        "flyfi",
        "flynet",
        "gogoinflight",
        "golonline",
        "iberiawifi",
        "icelandair",
        "jalwifi",
        "japanairlines",
        "klmwifi",
        "krisworld",
        "latamplay",
        "mhconnect",
        "mypal",
        "nordicsky",
        "norwegianinternet",
        "onair",
        "oryxcomms",
        "qantas",
        "ryanair",
        "saswifi",
        "shebaskyconnect",
        "singaporeair",
        "southwestwifi",
        "swissconnect",
        "tkwifi",
        "unitedwifi",
        "virginatlantic",
        "virginaustralia",
        "vistara",
        "westjet",
        "wingsconnect",
    ]

    /// Bare airline names (the patterns above with their Wi-Fi suffix removed) plus names too
    /// short or generic for substring matching. These must equal the whole normalized SSID —
    /// "delta" or "ba" as substrings would match countless unrelated home networks.
    private static let exactMatches: Set<String> = [
        "ac",
        "alaska",
        "ba",
        "delta",
        "gol",
        "iberia",
        "jal",
        "klm",
        "sas",
        "southwest",
        "tap",
        "tk",
        "united",
    ]

    static func matches(_ ssid: String) -> Bool {
        let normalized = normalize(ssid)
        guard !normalized.isEmpty else { return false }
        if exactMatches.contains(normalized) {
            return true
        }
        return patterns.contains { normalized.contains($0) }
    }

    private static func normalize(_ ssid: String) -> String {
        ssid.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
    }
}
