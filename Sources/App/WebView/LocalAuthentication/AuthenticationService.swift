import Foundation
import LocalAuthentication
import UIKit

protocol AuthenticationServiceProtocol {
    func authenticate()
}

class AuthenticationService: AuthenticationServiceProtocol {
    private let context = LAContext()

    func authenticate() {
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            authenticate(policy: .deviceOwnerAuthenticationWithBiometrics)
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            authenticate(policy: .deviceOwnerAuthentication)
        } else {
            print("Failed to authenticate")
        }
    }

    private func authenticate(policy: LAPolicy) {
        context.evaluatePolicy(policy, localizedReason: "Authentication required") { approved, error in
            if approved {
                print("success")
            } else {
                print("failure")
            }

            if let error {
                print(error)
            }
        }
    }
}
