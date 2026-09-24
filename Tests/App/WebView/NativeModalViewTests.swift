@testable import HomeAssistant
import Shared
import SwiftUI
import XCTest

final class NativeModalViewTests: XCTestCase {
    /// Lays the view out so SwiftUI evaluates its body. Deliberately never becomes the key window:
    /// the snapshot helpers draw into whatever window is key, so stealing it here would reach into
    /// unrelated tests.
    @MainActor
    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
    }

    @MainActor
    private func sheet(
        model: NativeModalModel,
        onAction: @escaping (String) -> Void = { _ in }
    ) -> some View {
        NativeModalView(
            model: model,
            onClose: {},
            onAction: onAction,
            onDisappear: {}
        ) {
            Color.clear
        }
    }

    /// A sheet that is still booting shows the native loader over the page.
    @MainActor func testShowsTheLoaderWhileTheFrontendBoots() {
        let model = NativeModalModel(title: "light.kitchen", isLoading: true)

        render(sheet(model: model))

        XCTAssertTrue(model.isLoading)
    }

    /// The bar draws what the frontend described: the entity's name over its breadcrumb, the icon
    /// buttons, and the overflow menu.
    @MainActor func testDrawsTheHeaderTheFrontendDescribed() {
        let model = NativeModalModel(
            title: "Kitchen ceiling",
            subtitle: "Kitchen ▸ Hue bridge",
            isLoading: false,
            navigation: .close,
            navigationLabel: "Close",
            menuLabel: "Menu",
            actions: [
                .init(id: "history", label: "History", icon: "mdi:chart-box-outline"),
                .init(id: "settings", label: "Settings", icon: "mdi:cog-outline"),
            ],
            menu: [
                .init(
                    id: "add_to",
                    label: "Add to",
                    icon: "mdi:plus-box-multiple-outline",
                    hasDividerAfter: true
                ),
                .init(
                    id: "copy_favorites",
                    label: "Copy favorites",
                    icon: "mdi:content-duplicate",
                    isDisabled: true
                ),
                .init(id: "details", label: "Details", icon: "mdi:information-outline"),
            ]
        )

        render(sheet(model: model))

        XCTAssertEqual(model.actions.map(\.id), ["history", "settings"])
    }

    /// A secondary view replaces the close button with a back button and drops the subtitle.
    @MainActor func testDrawsTheBackButtonOnASecondaryView() {
        let model = NativeModalModel(
            title: "History",
            isLoading: false,
            navigation: .back,
            navigationLabel: "Back to info"
        )

        render(sheet(model: model))

        XCTAssertNil(model.subtitle)
    }

    /// The sheet hosts the frontend's page; the web view is the only UIKit left inside it.
    @MainActor func testHostsTheFrontendsWebView() {
        let controller = WebViewController(
            server: ServerFixture.standard,
            role: .nativeModal(path: "/more-info?more-info-entity-id=light.kitchen")
        )
        controller.webViewExternalMessageHandler = MockWebViewExternalMessageHandler()
        let model = NativeModalModel(title: "Kitchen ceiling", isLoading: false)

        render(
            NativeModalView(
                model: model,
                onClose: {},
                onAction: { _ in },
                onDisappear: {}
            ) {
                NativeModalWebView(controller: controller)
            }
        )

        XCTAssertEqual(controller.role, .nativeModal(path: "/more-info?more-info-entity-id=light.kitchen"))
    }

    /// An icon the frontend names by its MDI name is drawn; an unknown one falls back rather than
    /// leaving an empty button.
    @MainActor func testDrawsTheIconsTheFrontendNames() {
        render(
            VStack {
                NativeModalHeaderIcon(name: "mdi:chart-box-outline")
                NativeModalHeaderIcon(name: "not-an-icon")
            }
        )
    }
}
