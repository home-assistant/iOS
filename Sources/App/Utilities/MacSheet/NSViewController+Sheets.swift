#if os(macOS)
import AppKit
import ObjectiveC
import SwiftUI

private var swiftUISheetPresentationsKey: UInt8 = 0
private var closingSheetPresentationsKey: UInt8 = 0
private var sheetPresenterKey: UInt8 = 0

/// Sheets on a Mac window, for code that presents controllers the way it does on iOS. A controller holding
/// a SwiftUI screen goes in a sheet SwiftUI owns, so that the screen can dismiss itself; any other
/// controller goes in an AppKit sheet.
extension NSViewController {
    private enum SheetConstants {
        /// The size a screen opens at when its controller does not ask for one. A sheet sized to fit a
        /// screen built for a phone would otherwise collapse to the width of its narrowest row.
        static let defaultSize = CGSize(width: 560, height: 640)
    }

    private var swiftUISheetPresentations: [MacSwiftUISheetPresentation] {
        get { objc_getAssociatedObject(self, &swiftUISheetPresentationsKey) as? [MacSwiftUISheetPresentation] ?? [] }
        set {
            objc_setAssociatedObject(self, &swiftUISheetPresentationsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// Sheets told to close, kept until SwiftUI reports them gone so their hosts can be taken down then.
    private var closingSheetPresentations: [MacSwiftUISheetPresentation] {
        get { objc_getAssociatedObject(self, &closingSheetPresentationsKey) as? [MacSwiftUISheetPresentation] ?? [] }
        set {
            objc_setAssociatedObject(self, &closingSheetPresentationsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// For a controller shown through `presentSheet(_:)` in a SwiftUI sheet, the controller that did it.
    private var swiftUISheetPresenter: NSViewController? {
        get { (objc_getAssociatedObject(self, &sheetPresenterKey) as? WeakReference)?.controller }
        set {
            objc_setAssociatedObject(
                self,
                &sheetPresenterKey,
                newValue.map(WeakReference.init(controller:)),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    private final class WeakReference {
        weak var controller: NSViewController?

        init(controller: NSViewController) {
            self.controller = controller
        }
    }

    /// The controllers presented from this one as sheets, oldest first.
    var presentedSheets: [NSViewController] {
        (presentedViewControllers ?? []) + swiftUISheetPresentations.map(\.carrier)
    }

    /// The content of a sheet on this controller's window that is not in `presentedSheets`, such as one
    /// SwiftUI put up itself, unless that sheet is on its way out.
    var foreignSheetContentController: NSViewController? {
        guard let sheet = view.window?.attachedSheet, let content = sheet.contentViewController else { return nil }
        let closing = closingSheetPresentations.contains { $0.contentController?.view.window === sheet }
        return closing ? nil : content
    }

    /// The controller to present from in order to land on top of this one: for a SwiftUI screen shown in a
    /// sheet, the controller SwiftUI hosts it in; otherwise the controller itself.
    var sheetContentController: NSViewController {
        swiftUISheetPresenter?.swiftUISheetPresentations.first { $0.carrier === self }?.contentController ?? self
    }

    func presentSheet(_ viewController: NSViewController) {
        guard let carrier = viewController as? MacSwiftUIScreenCarrying else {
            presentAsSheet(viewController)
            return
        }

        let size: CGSize? = if viewController.sizesSheetToContent {
            nil
        } else if viewController.preferredContentSize != .zero {
            viewController.preferredContentSize
        } else {
            SheetConstants.defaultSize
        }
        let model = MacSwiftUISheetModel(screen: carrier.carriedScreen, size: size)
        // Held weakly by the host it is about to own, which is created first.
        weak var resolving: MacSwiftUISheetPresentation?
        let host = NSHostingController(rootView: MacSwiftUISheetHostView(model: model) { controller in
            resolving?.contentController = controller
        })
        let record = MacSwiftUISheetPresentation(carrier: viewController, model: model, host: host)
        resolving = record
        model.onDismiss = { [weak self, weak record] in
            guard let self, let record else { return }
            record.host.view.removeFromSuperview()
            record.host.removeFromParent()
            record.carrier.swiftUISheetPresenter = nil
            swiftUISheetPresentations.removeAll { $0 === record }
            closingSheetPresentations.removeAll { $0 === record }
        }

        viewController.swiftUISheetPresenter = self
        swiftUISheetPresentations.append(record)
        addChild(host)
        host.view.frame = .zero
        view.addSubview(host.view)
    }

    /// Closes this controller's sheet, whichever kind it was presented in. A SwiftUI sheet leaves the
    /// stack at once, so whatever is presented next goes on what is under it rather than in it.
    func dismissSheet() {
        if let presenter = swiftUISheetPresenter,
           let presentation = presenter.swiftUISheetPresentations.first(where: { $0.carrier === self }) {
            presenter.close(presentation)
        } else {
            dismiss(nil)
        }
    }

    /// Closes every sheet presented from this controller, newest first.
    func dismissPresentedSheets() {
        for presentation in swiftUISheetPresentations.reversed() {
            close(presentation)
        }
        for presented in (presentedViewControllers ?? []).reversed() {
            dismiss(presented)
        }
    }

    private func close(_ presentation: MacSwiftUISheetPresentation) {
        swiftUISheetPresentations.removeAll { $0 === presentation }
        closingSheetPresentations.append(presentation)
        presentation.model.isPresented = false
    }
}
#endif
