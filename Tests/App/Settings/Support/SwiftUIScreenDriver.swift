import SwiftUI
import UIKit

/// Hosts a SwiftUI screen in an off-screen window so a test can lay it out and then drive it the
/// way a person would: tap list rows, follow navigation links, flip segmented pickers and toggles.
///
/// The window is never made key: snapshot helpers draw into whatever window is key, so stealing it
/// here would reach into unrelated tests.
@MainActor
final class SwiftUIScreenDriver {
    let window: UIWindow
    let host: UIViewController

    init(
        _ view: some View,
        size: CGSize = CGSize(width: 390, height: 2400),
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
        settle()
    }

    /// Hosts `view` and waits for its first layout pass, its `onAppear` and `task` work included.
    static func show(
        _ view: some View,
        size: CGSize = CGSize(width: 390, height: 2400),
        inNavigationStack: Bool = true
    ) async -> SwiftUIScreenDriver {
        let driver = SwiftUIScreenDriver(view, size: size, inNavigationStack: inNavigationStack)
        await driver.settle()
        return driver
    }

    /// Tears the window down so the hosted view disappears (and its `onDisappear` runs).
    func close() {
        window.isHidden = true
        window.rootViewController = nil
    }

    /// Lays the screen out and hands the main thread back to its run loop for a few turns, so
    /// SwiftUI updates, main-queue blocks and main-actor tasks the screen started get to run.
    func settle(_ turns: Int = 3) async {
        for _ in 0 ..< turns {
            window.setNeedsLayout()
            window.layoutIfNeeded()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    /// Synchronous variant for synchronous tests: spins the run loop in place. Main-queue blocks and
    /// main-actor tasks the screen starts cannot run until the test returns; use the async variant
    /// when the screen's work goes through them.
    func settle(_ turns: Int = 3) {
        for _ in 0 ..< turns {
            window.setNeedsLayout()
            window.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
    }

    /// Synchronous variant of `waitUntil` (see `settle()` for its limits).
    @discardableResult
    func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return false }
            settle(1)
        }
        return true
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

    /// The navigation controller being driven: the one in a presented sheet when there is one,
    /// otherwise the hosted screen's own.
    var navigationController: UINavigationController? {
        if let presented, let sheet: UINavigationController = Self.firstDescendant(of: presented) {
            return sheet
        }
        return Self.firstDescendant(of: host)
    }

    /// How many screens are on the navigation stack (1 = the root).
    var depth: Int {
        navigationController?.viewControllers.count ?? 0
    }

    /// The view of the screen currently on top of the navigation stack.
    var topView: UIView {
        navigationController?.topViewController?.view ?? host.view
    }

    func pop() async {
        let before = depth
        navigationController?.popViewController(animated: false)
        await waitUntil { depth < before }
    }

    func popToRoot() async {
        navigationController?.popToRootViewController(animated: false)
        await waitUntil { depth <= 1 }
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

    /// How many rows a section of the list on top has (0 when it has no such section).
    func rowCount(inSection section: Int) -> Int {
        guard let list, section < list.numberOfSections else { return 0 }
        return list.numberOfItems(inSection: section)
    }

    /// How many sections the list on top has.
    var sectionCount: Int {
        list?.numberOfSections ?? 0
    }

    /// Pulls the list on top down to refresh: fires its `.refreshable` action through the list's
    /// refresh control. Returns whether the list has one.
    @discardableResult
    func pullToRefresh() async -> Bool {
        guard let control = list?.refreshControl else { return false }
        control.beginRefreshing()
        control.sendActions(for: .valueChanged)
        await settle()
        return true
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
        // SwiftUI follows navigation links on selection and runs row buttons as the primary action.
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

    /// Taps a row that holds a navigation link and waits for the pushed screen.
    @discardableResult
    func push(_ indexPath: IndexPath, timeout: TimeInterval = 10) async -> Bool {
        let before = depth
        await tapRow(indexPath)
        return await waitUntil(timeout: timeout) { depth > before }
    }

    /// Follows every navigation row of the screen on top, one at a time, coming back after each.
    /// Rows that push nothing are tapped and left alone, so only use it on screens whose buttons are
    /// harmless. Returns how many rows pushed a screen.
    @discardableResult
    func pushEveryRow(timeout: TimeInterval = 1, onEach: (() async -> Void)? = nil) async -> Int {
        var pushed = 0
        for indexPath in rows {
            let before = depth
            guard await push(indexPath, timeout: timeout) else { continue }
            pushed += 1
            await onEach?()
            navigationController?.popToViewController(
                navigationController?.viewControllers[before - 1] ?? host,
                animated: false
            )
            await waitUntil { depth == before }
        }
        return pushed
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

    /// Picks a segment of the first segmented picker on screen.
    func selectSegment(_ index: Int, control: Int = 0) async {
        let controls = views(of: UISegmentedControl.self, in: topView)
        guard control < controls.count else { return }
        controls[control].selectedSegmentIndex = index
        controls[control].sendActions(for: .valueChanged)
        await settle()
    }

    /// Flips every switch on the screen on top.
    func toggleSwitches() async {
        for toggle in views(of: UISwitch.self, in: topView) {
            toggle.setOn(!toggle.isOn, animated: false)
            toggle.sendActions(for: .valueChanged)
        }
        await settle()
    }

    /// Presses the first stepper on the screen on top `count` times (`+` when positive, `-` when
    /// negative), one press per update so SwiftUI sees each step.
    func step(_ count: Int) async {
        guard let stepper = views(of: UIStepper.self, in: topView).first else { return }
        for _ in 0 ..< abs(count) {
            stepper.value += count > 0 ? stepper.stepValue : -stepper.stepValue
            stepper.sendActions(for: .valueChanged)
            await settle(1)
        }
    }

    /// Types into every text field on the screen on top.
    func type(_ text: String) async {
        for field in views(of: UITextField.self, in: topView) {
            field.text = text
            field.sendActions(for: .editingChanged)
        }
        await settle()
    }

    // MARK: - Navigation bar

    /// The navigation bar buttons of the screen on top, trailing ones first.
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

    /// Taps the navigation bar button of the screen on top whose title is `title`. Returns whether
    /// there was one.
    @discardableResult
    func tapBarButton(titled title: String) async -> Bool {
        guard let index = barButtons.firstIndex(where: {
            $0.title == title || $0.accessibilityLabel == title
        }) else {
            print("SwiftUIScreenDriver: no bar button \(title) in \(barButtons.map { $0.title ?? "-" })")
            return false
        }
        await tapBarButton(index)
        return true
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
        host.dismiss(animated: false)
        await waitUntil { presented == nil }
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
