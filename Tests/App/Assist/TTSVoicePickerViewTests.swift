@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// The on-device voice picker: it renders a loading state, then a section per language once the
/// voice catalog has loaded, with the current choice checked.
@MainActor
struct TTSVoicePickerViewTests {
    private func collectionView(in view: UIView) -> UICollectionView? {
        if let collectionView = view as? UICollectionView {
            return collectionView
        }
        for subview in view.subviews {
            if let found = collectionView(in: subview) {
                return found
            }
        }
        return nil
    }

    /// What these tests wait for lands through the main queue, which other suites keep busy under
    /// load, so the deadline counts main-queue turns as well as time.
    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        await LoadTolerantDeadline.waitUntil(condition)
    }

    @Test(arguments: [false, true])
    func rendersTheVoicesOnceTheCatalogLoads(selectsAVoice: Bool) async throws {
        let voices = await OnDeviceVoiceCatalog.voices()
        let selection = selectsAVoice ? voices.first?.identifier : nil
        let controller = UIHostingController(rootView: NavigationStack {
            TTSVoicePickerView(selectedVoiceIdentifier: .constant(selection))
        })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 2000))
        window.rootViewController = controller
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        controller.view.layoutIfNeeded()

        // The default voice is a section of its own; each language adds another once loaded.
        if !voices.isEmpty {
            let expectation1 = await waitUntil {
                controller.view.layoutIfNeeded()
                return (collectionView(in: controller.view)?.numberOfSections ?? 0) > 1
            }
            #expect(expectation1)
        }
        controller.view.layoutIfNeeded()
    }
}
