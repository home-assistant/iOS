import CarPlay
import Foundation

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
    func pushTemplate(_ templateToPush: CPTemplate, animated: Bool, completion: ((Bool, Error?) -> Void)?)
    func popTemplate(animated: Bool, completion: ((Bool, Error?) -> Void)?)
    func popToRootTemplate(animated: Bool, completion: ((Bool, Error?) -> Void)?)
}

extension CPInterfaceController: CarPlayNavigationPresenting {}
