import Foundation

public enum ExternalLink {
    public static var companionAppDocs = URL(string: "https://companion.home-assistant.io")!
    public static var discord = URL(string: "https://discord.com/channels/330944238910963714/1284965926336335993")!
    public static var githubReportIssue = URL(string: "https://github.com/home-assistant/iOS/issues/new/choose")!
    public static func githubSearchIssue(domain: String) -> URL? {
        URL(string: "https://github.com/home-assistant/iOS/search?q=\(domain)&type=issues")
    }
}
