import CarPlay
@testable import HomeAssistant

/// Stands in for `CPInterfaceController` when a test drives the screens a template pushes: records
/// every push, pop and presentation, and runs completions at once, as a settled transition would.
final class FakeCarPlayNavigator: CarPlayNavigationPresenting {
    var presentedTemplate: CPTemplate?
    /// The stack as CarPlay would hold it: root first, grown by pushes and shrunk by pops.
    private(set) var templates: [CPTemplate] = []
    /// Every push ever made, in order, whether or not it has since been popped.
    private(set) var pushedTemplates: [CPTemplate] = []
    private(set) var presentedTemplates: [CPTemplate] = []
    private(set) var popCount = 0
    private(set) var popToRootCount = 0
    private(set) var dismissCount = 0
    /// Errors handed to push and dismiss completions, to exercise a transition CarPlay rejects.
    var pushError: Error?
    var dismissError: Error?

    func pushTemplate(_ templateToPush: CPTemplate, animated: Bool, completion: ((Bool, Error?) -> Void)?) {
        pushedTemplates.append(templateToPush)
        if pushError == nil {
            templates.append(templateToPush)
        }
        completion?(pushError == nil, pushError)
    }

    func popTemplate(animated: Bool, completion: ((Bool, Error?) -> Void)?) {
        popCount += 1
        if !templates.isEmpty {
            templates.removeLast()
        }
        completion?(true, nil)
    }

    func popToRootTemplate(animated: Bool, completion: ((Bool, Error?) -> Void)?) {
        popToRootCount += 1
        templates = Array(templates.prefix(1))
        completion?(true, nil)
    }

    func presentTemplate(_ templateToPresent: CPTemplate, animated: Bool, completion: ((Bool, Error?) -> Void)?) {
        presentedTemplates.append(templateToPresent)
        presentedTemplate = templateToPresent
        completion?(true, nil)
    }

    func dismissTemplate(animated: Bool, completion: ((Bool, Error?) -> Void)?) {
        dismissCount += 1
        presentedTemplate = nil
        completion?(dismissError == nil, dismissError)
    }
}

/// Reading and tapping the rows of CarPlay list templates, as a driver would.
enum CarPlayTestRows {
    static func listItems(_ template: CPListTemplate?) -> [CPListItem] {
        (template?.sections ?? []).flatMap(\.items).compactMap { $0 as? CPListItem }
    }

    static func texts(_ template: CPListTemplate?) -> [String] {
        listItems(template).map { $0.text ?? "" }
    }

    static func row(_ template: CPListTemplate?, _ text: String) -> CPListItem? {
        listItems(template).first { $0.text == text }
    }

    static func tap(_ item: CPListItem?) {
        guard let item else { return }
        item.handler?(item, {})
    }

    static func tapImageRow(_ item: CPListImageRowItem?, index: Int) {
        guard let item else { return }
        item.listImageRowHandler?(item, index, {})
    }

    static func action(_ template: CPTemplate?, _ title: String) -> CPAlertAction? {
        if let sheet = template as? CPActionSheetTemplate {
            return sheet.actions.first { $0.title == title }
        }
        if let alert = template as? CPAlertTemplate {
            return alert.actions.first { $0.title == title }
        }
        return nil
    }

    static func run(_ action: CPAlertAction?) {
        guard let action else { return }
        action.handler(action)
    }
}

/// Polls `condition` on the main actor until it holds, giving up (returning false) after `timeout`.
@MainActor
func carPlayEventually(timeout: TimeInterval = 10, _ condition: () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        guard Date() < deadline else { return false }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
    return true
}
