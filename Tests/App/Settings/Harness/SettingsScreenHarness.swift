import SwiftUI
import UIKit

/// Hosts a settings screen in an off-screen window so a test can lay it out, let its `onAppear` and
/// `task` work run, and then drive it: tap list rows, follow navigation links, flip switches, type
/// into fields. A SwiftUI button is reachable when it makes up a list row (tap the row), so wrap a view
/// in a `List` to drive its button.
///
/// The window is never made key: snapshot helpers draw into whatever window is key, so stealing it
/// here would reach into unrelated tests.
@MainActor
final class SettingsScreenHarness {
    let window: UIWindow
    let host: UIViewController

    init(
        _ view: some View,
        size: CGSize = CGSize(width: 390, height: 2000),
        inNavigationStack: Bool = true
    ) {
        if inNavigationStack {
            self.host = UIHostingController(rootView: NavigationStack { view })
        } else {
            self.host = UIHostingController(rootView: view)
        }
        self.window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.isHidden = false
        window.setNeedsLayout()
        window.layoutIfNeeded()
    }

    /// Hosts `view` and waits for its first layout pass, `onAppear` and `task` work included.
    static func show(
        _ view: some View,
        size: CGSize = CGSize(width: 390, height: 2000),
        inNavigationStack: Bool = true
    ) async -> SettingsScreenHarness {
        let harness = SettingsScreenHarness(view, size: size, inNavigationStack: inNavigationStack)
        await harness.settle()
        return harness
    }

    /// Tears the window down so the hosted view disappears (and its `onDisappear` runs).
    func close() async {
        host.presentedViewController?.dismiss(animated: false)
        window.isHidden = true
        window.rootViewController = nil
        await Task.yield()
    }

    /// Lays the screen out and hands the main actor back for a few turns, so SwiftUI updates,
    /// main-queue blocks and main-actor tasks the screen started get to run.
    func settle(_ turns: Int = 3) async {
        for _ in 0 ..< turns {
            window.setNeedsLayout()
            window.layoutIfNeeded()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    /// Polls `condition` while the main run loop keeps turning, up to `timeout` seconds.
    @discardableResult
    func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return false }
            await settle(1)
        }
        return true
    }

    // MARK: - Navigation

    var navigationController: UINavigationController? {
        Self.firstDescendant(of: presented ?? host) ?? Self.firstDescendant(of: host)
    }

    /// How many screens are on the navigation stack (1 = the root).
    var depth: Int {
        navigationController?.viewControllers.count ?? 0
    }

    /// The view of the screen on top.
    var topView: UIView {
        if let presented, !(presented is UIAlertController) {
            return navigationController?.topViewController?.view ?? presented.view
        }
        return navigationController?.topViewController?.view ?? host.view
    }

    func pop() async {
        let before = depth
        navigationController?.popViewController(animated: false)
        await waitUntil { depth < before }
    }

    // MARK: - Lists

    /// The list (collection view) of the screen on top.
    var list: UICollectionView? {
        views(of: UICollectionView.self, in: topView).first
    }

    /// Every row of the list on top, in order.
    var rows: [IndexPath] {
        guard let list else { return [] }
        return (0 ..< list.numberOfSections).flatMap { section in
            (0 ..< list.numberOfItems(inSection: section)).map { IndexPath(item: $0, section: section) }
        }
    }

    /// Taps a list row: runs its button action or follows its navigation link.
    func tapRow(_ indexPath: IndexPath) async {
        guard let list, indexPath.section < list.numberOfSections,
              indexPath.item < list.numberOfItems(inSection: indexPath.section) else { return }
        list.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        await settle(1)
        let delegate = list.delegate
        if delegate?.collectionView?(list, shouldHighlightItemAt: indexPath) ?? true {
            delegate?.collectionView?(list, didHighlightItemAt: indexPath)
        }
        if delegate?.collectionView?(list, shouldSelectItemAt: indexPath) ?? true {
            list.selectItem(at: indexPath, animated: false, scrollPosition: [])
            delegate?.collectionView?(list, didSelectItemAt: indexPath)
        }
        if delegate?.collectionView?(list, canPerformPrimaryActionForItemAt: indexPath) == true {
            delegate?.collectionView?(list, performPrimaryActionForItemAt: indexPath)
        }
        delegate?.collectionView?(list, didUnhighlightItemAt: indexPath)
        await settle()
    }

    /// Taps every row of the list on top once, coming back to this screen after each push.
    func tapEveryRow(skipping skipped: Set<IndexPath> = []) async {
        let rootDepth = depth
        for indexPath in rows where !skipped.contains(indexPath) {
            await tapRow(indexPath)
            await dismissPresented()
            while depth > rootDepth {
                await pop()
            }
        }
    }

    /// Taps a row holding a navigation link and waits for the pushed screen.
    @discardableResult
    func push(_ indexPath: IndexPath) async -> Bool {
        let before = depth
        await tapRow(indexPath)
        return await waitUntil(timeout: 5) { depth > before }
    }

    // MARK: - Controls

    func views<T: UIView>(of type: T.Type, in root: UIView? = nil) -> [T] {
        var found: [T] = []
        var stack: [UIView] = [root ?? window]
        while let view = stack.popLast() {
            if let match = view as? T { found.append(match) }
            stack.append(contentsOf: view.subviews.reversed())
        }
        return found
    }

    /// Flips every switch on the screen on top.
    func toggleSwitches() async {
        for toggle in views(of: UISwitch.self, in: topView) {
            toggle.setOn(!toggle.isOn, animated: false)
            toggle.sendActions(for: .valueChanged)
        }
        await settle()
    }

    /// Types into every text field on the screen on top and ends editing, as if focus moved away.
    func type(_ text: String) async {
        for field in views(of: UITextField.self, in: topView) {
            field.text = text
            field.sendActions(for: .editingChanged)
            _ = field.delegate?.textFieldShouldReturn?(field)
            field.sendActions(for: .editingDidEndOnExit)
        }
        await settle()
    }

    /// Types into the search field of the screen on top (`.searchable`).
    func search(_ text: String) async {
        guard let controller = navigationController?.topViewController?.navigationItem.searchController else {
            return
        }
        controller.searchBar.text = text
        controller.searchBar.delegate?.searchBar?(controller.searchBar, textDidChange: text)
        controller.searchResultsUpdater?.updateSearchResults(for: controller)
        await settle()
    }

    // MARK: - Navigation bar

    /// The navigation bar buttons of the screen on top.
    var barButtons: [UIBarButtonItem] {
        guard let item = navigationController?.topViewController?.navigationItem else { return [] }
        let grouped = (item.trailingItemGroups + item.leadingItemGroups).flatMap(\.barButtonItems)
        let plain = (item.rightBarButtonItems ?? []) + (item.leftBarButtonItems ?? [])
        return plain + grouped.filter { candidate in !plain.contains { $0 === candidate } }
    }

    /// Taps a navigation bar button of the screen on top.
    func tapBarButton(_ index: Int = 0) async {
        let buttons = barButtons
        guard index < buttons.count else { return }
        let item = buttons[index]
        if let action = item.primaryAction {
            action.perform(NSSelectorFromString("performWithSender:target:"), with: item, with: nil)
        } else if let selector = item.action {
            UIApplication.shared.sendAction(selector, to: item.target, from: item, for: nil)
        } else if let custom = item.customView {
            for control in views(of: UIControl.self, in: custom) {
                control.sendActions(for: .touchUpInside)
            }
        }
        await settle()
    }

    // MARK: - Alerts and sheets

    /// The controller presented on top of the screen (an alert, a confirmation dialog or a sheet).
    var presented: UIViewController? {
        var controller: UIViewController = host
        while let next = controller.presentedViewController {
            controller = next
        }
        return controller === host ? nil : controller
    }

    /// The alert or confirmation dialog on top, if any.
    var alert: UIAlertController? {
        presented as? UIAlertController
    }

    /// Taps the button of the alert on top whose title is `title` (the first one when `nil`).
    func tapAlertButton(_ title: String? = nil) async {
        guard let alert else { return }
        let action = alert.actions.first { title == nil || $0.title == title }
        typealias Handler = @convention(block) (UIAlertAction) -> Void
        if let action, let block = action.value(forKey: "handler") {
            let handler = unsafeBitCast(block as AnyObject, to: Handler.self)
            handler(action)
        }
        await dismissPresented()
    }

    /// Dismisses whatever is presented on top of the screen.
    func dismissPresented() async {
        guard presented != nil else { return }
        host.dismiss(animated: false)
        await waitUntil(timeout: 5) { presented == nil }
    }

    private static func firstDescendant<T: UIViewController>(of controller: UIViewController) -> T? {
        var stack = [controller]
        while let next = stack.popLast() {
            if let match = next as? T { return match }
            stack.append(contentsOf: next.children)
        }
        return nil
    }
}
