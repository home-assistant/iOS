@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing
import UIKit

/// The banner the web view shows for server alerts and connection notices: when two requests count
/// as the same banner, how the overlay is laid out, and how its action, dimming and timer dismiss it.
@Suite(.sharedState)
@MainActor
struct DefaultBannerPresenterTests {
    private final class RecordingBannerPresenter: BannerPresenter {
        private(set) var shown: [BannerRequest] = []
        private(set) var hidden: [String] = []

        func show(on viewController: UIViewController, request: BannerRequest) {
            shown.append(request)
        }

        func hide(id: String) {
            hidden.append(id)
        }
    }

    private final class Counter {
        var actions = 0
        var dismissals = 0
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    private func makeHost() -> UIViewController {
        let controller = UIViewController()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        return controller
    }

    private func overlays(in host: UIViewController) -> [UIView] {
        host.view.subviews
    }

    private func subviews<T: UIView>(of type: T.Type, in view: UIView) -> [T] {
        view.subviews.flatMap { subview -> [T] in
            ((subview as? T).map { [$0] } ?? []) + subviews(of: type, in: subview)
        }
    }

    private func request(
        id: String = UUID().uuidString,
        title: String? = "Title",
        message: String? = "Message",
        duration: BannerDuration = .forever,
        dimming: BannerDimming = .gray(interactive: true),
        action: BannerAction? = nil,
        counter: Counter? = nil
    ) -> BannerRequest {
        BannerRequest(
            id: id,
            title: title,
            message: message,
            duration: duration,
            dimming: dimming,
            style: .warning,
            action: action,
            onDismiss: { counter?.dismissals += 1 },
            dimmingAccessibilityLabel: "Dismiss"
        )
    }

    // MARK: - Value semantics

    @Test func durationsAreEqualOnlyWhenTheyMatch() {
        #expect(BannerDuration.forever == .forever)
        #expect(BannerDuration.seconds(2) == .seconds(2))
        #expect(BannerDuration.seconds(2) != .seconds(3))
        #expect(BannerDuration.seconds(2) != .forever)
    }

    @Test func dimmingIsInteractiveAndTintedOnlyWhenGray() {
        #expect(!BannerDimming.none.isInteractive)
        #expect(BannerDimming.none.color == .clear)
        #expect(BannerDimming.gray(interactive: true).isInteractive)
        #expect(!BannerDimming.gray(interactive: false).isInteractive)
        #expect(BannerDimming.gray(interactive: false).color != .clear)
    }

    @Test func stylesCompareByTheirColors() {
        #expect(BannerStyle.card(backgroundColor: .red, foregroundColor: .white) == .init(
            backgroundColor: .red,
            foregroundColor: .white
        ))
        #expect(BannerStyle.card(backgroundColor: .red, foregroundColor: .white) != .warning)
    }

    @Test func requestsWithTheSameIdOrContentPresentTheSameBanner() {
        let action = BannerAction(title: "Open", tintColor: .white, handler: {})
        let base = request(id: "a", action: action)

        #expect(base.matchesPresentation(of: request(id: "a", title: "Other")))
        #expect(base.matchesPresentation(of: request(id: "b", action: action)))
        #expect(!base.matchesPresentation(of: request(id: "b", title: "Other", action: action)))
        #expect(!base.matchesPresentation(of: request(id: "b")))
        #expect(!request(id: "c").matchesPresentation(of: request(id: "d", action: action)))
        #expect(request(id: "c").matchesPresentation(of: request(id: "d")))
        #expect(!base.matchesPresentation(of: request(
            id: "b",
            action: BannerAction(title: "Open", image: UIImage(systemName: "xmark"), tintColor: .white, handler: {})
        )))
        #expect(!base.matchesPresentation(of: request(
            id: "b",
            action: BannerAction(title: "Open", tintColor: .white, dismissOnTap: false, handler: {})
        )))
    }

    // MARK: - Presentation

    @Test func showingABannerAddsAnOverlayWithItsTextAndAction() async throws {
        let presenter = DefaultBannerPresenter()
        let host = makeHost()
        let banner = request(
            id: "banner",
            action: BannerAction(
                title: "Open",
                image: UIImage(systemName: "arrow.up.right"),
                tintColor: .white,
                accessibilityLabel: "Open link",
                handler: {}
            )
        )

        presenter.show(on: host, request: banner)

        let expectation1 = await waitUntil { overlays(in: host).count == 1 }
        #expect(expectation1)
        let overlay = try #require(overlays(in: host).first)
        let texts = subviews(of: UILabel.self, in: overlay).compactMap(\.text)
        #expect(texts.contains("Title"))
        #expect(texts.contains("Message"))
        #expect(subviews(of: UIView.self, in: overlay).contains { $0.accessibilityIdentifier == "banner" })
        let actionButton = try #require(
            subviews(of: UIButton.self, in: overlay)
                .first { $0.title(for: .normal) == "Open" }
        )
        #expect(actionButton.accessibilityLabel == "Open link")
        #expect(!actionButton.isHidden)
    }

    @Test func aBannerWithoutTextOrActionHidesThem() async throws {
        let presenter = DefaultBannerPresenter()
        let host = makeHost()

        presenter.show(on: host, request: request(title: nil, message: nil, dimming: .none))

        let expectation2 = await waitUntil { overlays(in: host).count == 1 }
        #expect(expectation2)
        let overlay = try #require(overlays(in: host).first)
        #expect(subviews(of: UILabel.self, in: overlay).allSatisfy { $0.isHidden || $0.text == nil })
        overlay.frame = host.view.bounds
        overlay.layoutIfNeeded()
        // Without dimming only the banner itself takes touches; the rest falls through to the page.
        #expect(!overlay.point(inside: CGPoint(x: 5, y: 5), with: nil))
    }

    @Test func interactiveDimmingTakesTouchesAcrossTheScreen() async throws {
        let presenter = DefaultBannerPresenter()
        let host = makeHost()

        presenter.show(on: host, request: request(dimming: .gray(interactive: true)))

        let expectation3 = await waitUntil { overlays(in: host).count == 1 }
        #expect(expectation3)
        let overlay = try #require(overlays(in: host).first)
        overlay.frame = host.view.bounds
        #expect(overlay.point(inside: CGPoint(x: 5, y: 5), with: nil))
    }

    @Test func showingTheSameBannerAgainKeepsTheOneOnScreen() async throws {
        let presenter = DefaultBannerPresenter()
        let host = makeHost()
        let banner = request(id: "same")

        presenter.show(on: host, request: banner)
        presenter.show(on: host, request: banner)
        let expectation4 = await waitUntil { overlays(in: host).count == 1 }
        #expect(expectation4)
        let first = try #require(overlays(in: host).first)

        // A different banner replaces it, which is how the test knows both earlier shows have run.
        presenter.show(on: host, request: request(id: "other", title: "Other"))
        let expectation5 = await waitUntil { overlays(in: host).first !== first }
        #expect(expectation5)
        #expect(overlays(in: host).count == 1)
    }

    @Test func tappingTheActionRunsItAfterTheBannerIsDismissed() async throws {
        let presenter = DefaultBannerPresenter()
        let host = makeHost()
        let counter = Counter()

        presenter.show(on: host, request: request(
            action: BannerAction(title: "Open", tintColor: .white, handler: { counter.actions += 1 }),
            counter: counter
        ))
        let expectation6 = await waitUntil { overlays(in: host).count == 1 }
        #expect(expectation6)
        let overlay = try #require(overlays(in: host).first)
        let button = try #require(subviews(of: UIButton.self, in: overlay).first { $0.title(for: .normal) == "Open" })

        button.sendActions(for: .touchUpInside)

        let expectation7 = await waitUntil { counter.actions == 1 }
        #expect(expectation7)
        let expectation8 = await waitUntil { overlays(in: host).isEmpty }
        #expect(expectation8)
        #expect(counter.dismissals == 1)
    }

    @Test func anActionThatKeepsTheBannerRunsStraightAway() async throws {
        let presenter = DefaultBannerPresenter()
        let host = makeHost()
        let counter = Counter()

        presenter.show(on: host, request: request(
            action: BannerAction(
                image: UIImage(systemName: "xmark"),
                tintColor: .white,
                dismissOnTap: false,
                handler: { counter.actions += 1 }
            ),
            counter: counter
        ))
        let expectation9 = await waitUntil { overlays(in: host).count == 1 }
        #expect(expectation9)
        let overlay = try #require(overlays(in: host).first)
        let button = try #require(subviews(of: UIButton.self, in: overlay).first { $0.image(for: .normal) != nil })

        button.sendActions(for: .touchUpInside)

        #expect(counter.actions == 1)
        #expect(overlays(in: host).count == 1)
        #expect(counter.dismissals == 0)
    }

    @Test(arguments: [true, false])
    func tappingTheDimmingDismissesOnlyWhenInteractive(interactive: Bool) async throws {
        let presenter = DefaultBannerPresenter()
        let host = makeHost()
        let counter = Counter()

        presenter.show(on: host, request: request(dimming: .gray(interactive: interactive), counter: counter))
        let expectation10 = await waitUntil { overlays(in: host).count == 1 }
        #expect(expectation10)
        let overlay = try #require(overlays(in: host).first)
        let background = try #require(subviews(of: UIButton.self, in: overlay).first)

        background.sendActions(for: .touchUpInside)

        if interactive {
            let expectation11 = await waitUntil { overlays(in: host).isEmpty }
            #expect(expectation11)
            #expect(counter.dismissals == 1)
        } else {
            #expect(overlays(in: host).count == 1)
            #expect(counter.dismissals == 0)
        }
    }

    @Test func hidingRemovesOnlyTheBannerItNames() async throws {
        let presenter = DefaultBannerPresenter()
        let host = makeHost()
        let counter = Counter()

        presenter.show(on: host, request: request(id: "shown", counter: counter))
        let expectation12 = await waitUntil { overlays(in: host).count == 1 }
        #expect(expectation12)

        presenter.hide(id: "another")
        presenter.hide(id: "shown")

        let expectation13 = await waitUntil { overlays(in: host).isEmpty }
        #expect(expectation13)
        #expect(counter.dismissals == 1)
    }

    @Test func aTimedBannerDismissesItself() async throws {
        let presenter = DefaultBannerPresenter()
        let host = makeHost()
        let counter = Counter()

        presenter.show(on: host, request: request(duration: .seconds(0.01), counter: counter))

        let expectation14 = await waitUntil { counter.dismissals == 1 }
        #expect(expectation14)
        let expectation15 = await waitUntil { overlays(in: host).isEmpty }
        #expect(expectation15)
    }

    // MARK: - Server alerts

    @Test func aServerAlertShowsAWarningBannerThatOpensItsLink() throws {
        let previousOpener = URLOpener.shared
        let opener = MockURLOpener()
        URLOpener.shared = opener
        defer { URLOpener.shared = previousOpener }
        let handledKey = "ServerAlerterViewedAlerts"
        let previousHandled = Current.settingsStore.prefs.stringArray(forKey: handledKey)
        defer { Current.settingsStore.prefs.set(previousHandled, forKey: handledKey) }

        let controller = WebViewController(server: .fake())
        let presenter = RecordingBannerPresenter()
        controller.bannerPresenter = presenter
        let link = try #require(URL(string: "https://example.com/alert"))
        let alert = ServerAlert(
            id: "alert-1",
            date: Date(),
            url: link,
            message: "Update now",
            adminOnly: false,
            ios: .init(min: nil, max: nil),
            core: .init(min: nil, max: nil)
        )

        controller.show(alert: alert)

        let shown = try #require(presenter.shown.first)
        #expect(shown.id == "alert-1")
        #expect(shown.message == "Update now")
        #expect(shown.duration == .forever)
        #expect(shown.dimming == .gray(interactive: true))
        #expect(shown.style == .warning)
        #expect(shown.action?.title == L10n.openLabel)

        shown.action?.handler()
        #expect(opener.openedURLs.map(\.url) == [link])

        shown.onDismiss?()
        #expect(Current.settingsStore.prefs.stringArray(forKey: handledKey)?.contains("alert-1") == true)
    }
}
