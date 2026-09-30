#if os(macOS)
import AppKit
import SwiftUI

/// Hosts a banner over the web view on the Mac: `MacBannerView` drawn by SwiftUI inside an AppKit view, with
/// the same entry points the iOS overlay gives `DefaultBannerPresenter`.
final class MacBannerOverlayView: NSView {
    private let request: BannerRequest
    private let model = MacBannerModel()
    private var hostingView: NSHostingView<MacBannerView>?

    var onDismissRequested: (() -> Void)?
    var onActionRequested: (() -> Void)?

    init(request: BannerRequest) {
        self.request = request
        super.init(frame: .zero)

        let hostingView = NSHostingView(rootView: MacBannerView(
            request: request,
            model: model,
            onDismiss: { [weak self] in self?.onDismissRequested?() },
            onAction: { [weak self] in self?.onActionRequested?() }
        ))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        self.hostingView = hostingView
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// A banner that does not dim the page only takes clicks on the banner itself, so the page beneath it
    /// stays usable.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hit = super.hitTest(point) else { return nil }
        if request.dimming.isInteractive {
            return hit
        }
        let pointInSelf = convert(point, from: superview)
        let bannerFrame = isFlipped ? model.bannerFrame : CGRect(
            x: model.bannerFrame.minX,
            y: bounds.height - model.bannerFrame.maxY,
            width: model.bannerFrame.width,
            height: model.bannerFrame.height
        )
        return bannerFrame.contains(pointInSelf) ? hit : nil
    }

    func present() {
        model.isPresented = true
    }

    func dismiss(animated: Bool, completion: @escaping () -> Void) {
        model.isPresented = false
        let finish = { [weak self] in
            self?.removeFromSuperview()
            completion()
        }
        if animated {
            DispatchQueue.main.asyncAfter(deadline: .now() + MacBannerView.animationDuration, execute: finish)
        } else {
            finish()
        }
    }
}
#endif
