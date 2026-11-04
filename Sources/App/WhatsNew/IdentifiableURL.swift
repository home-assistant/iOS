import Foundation

/// Wraps a URL so it can drive a `.sheet(item:)` presentation.
struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
