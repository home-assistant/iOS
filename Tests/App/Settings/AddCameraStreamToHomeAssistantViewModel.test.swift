@testable import HomeAssistant
@testable import Shared
import Testing

struct AddCameraStreamToHomeAssistantViewModelTests {
    @MainActor
    @Test func testCreatedUsesTheServerTitle() {
        let state = AddCameraStreamToHomeAssistantViewModel.resultState(
            for: .created(title: "iPhone Camera"),
            fallbackTitle: "Fallback Camera"
        )
        #expect(state == .succeeded(L10n.Sensors.CameraStream.AddToHomeAssistant.success("iPhone Camera")))
    }

    @MainActor
    @Test func testCreatedWithoutTitleFallsBack() {
        let state = AddCameraStreamToHomeAssistantViewModel.resultState(
            for: .created(title: ""),
            fallbackTitle: "Fallback Camera"
        )
        #expect(state == .succeeded(L10n.Sensors.CameraStream.AddToHomeAssistant.success("Fallback Camera")))
    }

    @MainActor
    @Test func testAlreadyConfiguredAbortIsExplained() {
        let state = AddCameraStreamToHomeAssistantViewModel.resultState(
            for: .aborted(reason: "already_configured"),
            fallbackTitle: ""
        )
        #expect(state == .failed(L10n.Sensors.CameraStream.AddToHomeAssistant.Error.alreadyConfigured))
    }

    @MainActor
    @Test func testOtherAbortReportsTheReason() {
        let state = AddCameraStreamToHomeAssistantViewModel.resultState(
            for: .aborted(reason: "single_instance_allowed"),
            fallbackTitle: ""
        )
        #expect(state == .failed(L10n.Sensors.CameraStream.AddToHomeAssistant.Error.flow("single_instance_allowed")))
    }

    @MainActor
    @Test func testCannotConnectFormError() {
        let state = AddCameraStreamToHomeAssistantViewModel.resultState(
            for: .form(flowID: "1", errors: ["base": "cannot_connect"]),
            fallbackTitle: ""
        )
        #expect(state == .failed(L10n.Sensors.CameraStream.AddToHomeAssistant.Error.cannotConnect))
    }

    @MainActor
    @Test func testInvalidAuthFormError() {
        let state = AddCameraStreamToHomeAssistantViewModel.resultState(
            for: .form(flowID: "1", errors: ["username": "invalid_auth"]),
            fallbackTitle: ""
        )
        #expect(state == .failed(L10n.Sensors.CameraStream.AddToHomeAssistant.Error.invalidAuth))
    }

    /// A form with no errors means the flow asked for something the app can't answer — reported as
    /// a failure rather than silently doing nothing.
    @MainActor
    @Test func testFormWithoutErrorsIsAFailure() {
        let state = AddCameraStreamToHomeAssistantViewModel.resultState(
            for: .form(flowID: "1", errors: [:]),
            fallbackTitle: ""
        )
        #expect(state == .failed(L10n.Sensors.CameraStream.AddToHomeAssistant.Error.flow("unknown")))
    }
}
