import Foundation
@testable import HomeAssistant
import Testing
import UIKit

@MainActor
struct SoftwareKeyboardObserverTests {
    private let screenHeight: CGFloat = 678

    @Test("A docked keyboard counts as shown; one parked below the screen or a hardware-keyboard bar does not")
    func frames() {
        let docked = CGRect(x: 0, y: 378, width: 466, height: 300)
        #expect(SoftwareKeyboardObserver.isShown(endFrame: docked, screenHeight: screenHeight))

        let hidden = CGRect(x: 0, y: 678, width: 466, height: 300)
        #expect(!SoftwareKeyboardObserver.isShown(endFrame: hidden, screenHeight: screenHeight))

        let assistantBar = CGRect(x: 0, y: 623, width: 466, height: 55)
        #expect(!SoftwareKeyboardObserver.isShown(endFrame: assistantBar, screenHeight: screenHeight))

        #expect(!SoftwareKeyboardObserver.isShown(endFrame: nil, screenHeight: screenHeight))
    }

    @Test("The observer follows keyboard frame changes and hide notifications")
    func followsNotifications() async throws {
        let center = NotificationCenter()
        let observer = SoftwareKeyboardObserver(notificationCenter: center, screenHeight: { 678 })
        #expect(!observer.isShown)

        center.post(
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            userInfo: [UIResponder.keyboardFrameEndUserInfoKey: CGRect(x: 0, y: 378, width: 466, height: 300)]
        )
        try await waitUntil { observer.isShown }
        #expect(observer.isShown)

        center.post(name: UIResponder.keyboardWillHideNotification, object: nil)
        try await waitUntil { !observer.isShown }
        #expect(!observer.isShown)
    }

    @Test("The default observer reads the main screen and listens to the default notification center")
    func defaultObserver() async throws {
        let observer = SoftwareKeyboardObserver()
        NotificationCenter.default.post(
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            userInfo: [UIResponder.keyboardFrameEndUserInfoKey: CGRect(x: 0, y: 0, width: 466, height: 300)]
        )
        try await waitUntil { observer.isShown }
        #expect(observer.isShown)
        NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification, object: nil)
        try await waitUntil { !observer.isShown }
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0 ..< 100 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}
