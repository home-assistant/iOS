import CarPlay
import Foundation
import Shared

/// The slice of `CPInterfaceController` that presenting a failure needs.
///
/// Narrowing it here lets the "one alert at a time" rule be exercised directly: `CPInterfaceController`
/// has no public initializer, so a test can't stand one up.
protocol CarPlayAlertPresenting: AnyObject {
    var presentedTemplate: CPTemplate? { get }
    func presentTemplate(_ templateToPresent: CPTemplate, animated: Bool, completion: ((Bool, Error?) -> Void)?)
    func dismissTemplate(animated: Bool, completion: ((Bool, Error?) -> Void)?)
}

extension CPInterfaceController: CarPlayAlertPresenting {}

/// The slice of `CPInterfaceController` that pushing and popping templates needs, narrowed for the
/// same reason as `CarPlayAlertPresenting`: tests drive the pushed screens through a double.
protocol CarPlayNavigationPresenting: CarPlayAlertPresenting {
    var templates: [CPTemplate] { get }
    func pushTemplate(_ templateToPush: CPTemplate, animated: Bool, completion: ((Bool, Error?) -> Void)?)
    func popTemplate(animated: Bool, completion: ((Bool, Error?) -> Void)?)
    func popToRootTemplate(animated: Bool, completion: ((Bool, Error?) -> Void)?)
}

extension CPInterfaceController: CarPlayNavigationPresenting {}

extension CarPlayNavigationPresenting {
    /// How many templates CarPlay lets an app stack, root included.
    static var maximumTemplateDepth: Int {
        5
    }

    /// `pushTemplate` that refuses what CarPlay would raise on and take the app down with: a sixth
    /// template on the stack (a double tap on a slow head unit got there) or one already on it.
    /// Returns whether the push was handed to CarPlay, so a caller commits the state behind the
    /// screen only once it is actually on its way.
    @discardableResult
    func pushTemplateWithinDepthLimit(
        _ templateToPush: CPTemplate,
        animated: Bool,
        completion: ((Bool, Error?) -> Void)? = nil
    ) -> Bool {
        let templates = templates
        guard templates.count < Self.maximumTemplateDepth else {
            Current.Log.error("CarPlay refused to push \(type(of: templateToPush)): \(templates.count) already stacked")
            completion?(false, nil)
            return false
        }
        guard !templates.contains(where: { $0 === templateToPush }) else {
            Current.Log.error("CarPlay refused to push \(type(of: templateToPush)): already on the stack")
            completion?(false, nil)
            return false
        }
        pushTemplate(templateToPush, animated: animated, completion: completion)
        return true
    }
}
