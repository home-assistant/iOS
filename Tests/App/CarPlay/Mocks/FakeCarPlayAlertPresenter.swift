import CarPlay
@testable import HomeAssistant

/// Stands in for `CPInterfaceController`, which has no public initializer, so the failure alert's
/// presentation rules can be exercised without a live CarPlay scene.
final class FakeCarPlayAlertPresenter: CarPlayAlertPresenting {
    var presentedTemplate: CPTemplate?
    private(set) var presentedTemplates: [CPTemplate] = []
    private(set) var dismissCount = 0

    func presentTemplate(_ templateToPresent: CPTemplate, animated: Bool, completion: ((Bool, Error?) -> Void)?) {
        presentedTemplates.append(templateToPresent)
        presentedTemplate = templateToPresent
        completion?(true, nil)
    }

    func dismissTemplate(animated: Bool, completion: ((Bool, Error?) -> Void)?) {
        dismissCount += 1
        presentedTemplate = nil
        completion?(true, nil)
    }
}
