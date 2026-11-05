import SwiftUI

/// A confirmation the secondary action of a `BaseOnboardingView` asks for before it runs, presented
/// from that button so the dialog is anchored to the control that opened it.
public struct BaseOnboardingConfirmation {
    public let title: String
    public let message: String
    public let confirmTitle: String
    public let confirmRole: ButtonRole?
    public let confirmIdentifier: String?
    public let action: () -> Void

    public init(
        title: String,
        message: String,
        confirmTitle: String,
        confirmRole: ButtonRole? = nil,
        confirmIdentifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.confirmRole = confirmRole
        self.confirmIdentifier = confirmIdentifier
        self.action = action
    }
}
