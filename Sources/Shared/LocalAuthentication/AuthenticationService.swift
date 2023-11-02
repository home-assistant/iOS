import Foundation
import LocalAuthentication
import UIKit

public protocol AuthenticationServiceProtocol {
    var delegate: AuthenticationServiceDelegate? { get set }
    func authenticate()
    func invalidate()
}

public protocol AuthenticationServiceDelegate: AnyObject {
    func didFinishAuthentication(authorized: Bool)
}

class AuthenticationService: AuthenticationServiceProtocol {
    private let context = LAContext()

    weak var delegate: AuthenticationServiceDelegate?

    func authenticate() {
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            authenticate(policy: .deviceOwnerAuthenticationWithBiometrics)
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            authenticate(policy: .deviceOwnerAuthentication)
        } else {
            Current.Log
                .error(
                    [
                        "Failed to authenticate with biometrics": "User context can't evaluate policy for device ownership",
                    ]
                )
        }
    }

    func invalidate() {
        context.invalidate()
    }

    private func authenticate(policy: LAPolicy) {
        context.evaluatePolicy(policy, localizedReason: "Authentication required") { [weak self] authorized, error in
            self?.delegate?.didFinishAuthentication(authorized: authorized)

            if let error {
                Current.Log.error(["Failed to evaluate policy for authentication": error.localizedDescription])
            }
        }
    }
}
