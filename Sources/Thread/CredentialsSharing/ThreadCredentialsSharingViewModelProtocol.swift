import Foundation

protocol ThreadCredentialsSharingViewModelProtocol: ObservableObject {
    var showOperationSuccess: Bool { get set }
    var showAlert: Bool { get set }
    var alertType: ThreadCredentialsAlertType? { get set }
    func mainOperation() async
}
