#if os(macOS)
import Foundation

/// What `MacBannerOverlayView` and the SwiftUI banner it hosts share: whether the banner is on screen, and
/// where it ended up, so the overlay knows which clicks are the banner's.
final class MacBannerModel: ObservableObject {
    @Published var isPresented = false
    var bannerFrame: CGRect = .zero
}
#endif
