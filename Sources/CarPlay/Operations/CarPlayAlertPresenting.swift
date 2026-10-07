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
