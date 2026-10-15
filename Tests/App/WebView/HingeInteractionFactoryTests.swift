import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing
import UIKit

@MainActor
struct HingeInteractionFactoryTests {
    private final class FakeHinge: NSObject {
        @objc let angle: CGFloat
        @objc let status: Int

        init(angle: CGFloat, status: Int) {
            self.angle = angle
            self.status = status
        }
    }

    private final class FakeUpdate: NSObject {
        @objc let hinge: FakeHinge?

        init(hinge: FakeHinge?) {
            self.hinge = hinge
        }
    }

    @objc(HAFakeHingeInteraction)
    private final class FakeHingeInteraction: NSObject, UIInteraction {
        let updateHandler: (NSObject, NSObject) -> Void
        private(set) weak var view: UIView?

        @objc init(updateHandler: @escaping (NSObject, NSObject) -> Void) {
            self.updateHandler = updateHandler
        }

        func willMove(to view: UIView?) {}

        func didMove(to view: UIView?) {
            self.view = view
        }
    }

    @Test("A hinge's radians and raw status become a reading")
    func readsTheHinge() {
        let update = FakeUpdate(hinge: FakeHinge(angle: .pi / 2, status: 2))
        let state = HingeInteractionFactory.state(from: update)
        #expect(state?.status == .partiallyOpen)
        #expect(abs((state?.angleDegrees ?? 0) - 90) < 0.0001)
    }

    @Test("An update without a hinge means the device has none")
    func updateWithoutHinge() {
        #expect(HingeInteractionFactory.state(from: FakeUpdate(hinge: nil)) == nil)
    }

    @Test("Something that isn't a hinge update reads as no hinge rather than throwing")
    func unrecognisedUpdate() {
        #expect(HingeInteractionFactory.state(from: NSObject()) == nil)
    }

    @Test("A class that isn't there builds nothing")
    func missingClass() {
        #expect(HingeInteractionFactory.makeInteraction(className: "HANoSuchInteraction") { _ in } == nil)
    }

    @Test("A class without the update handler initializer builds nothing")
    func classWithoutInitializer() {
        #expect(HingeInteractionFactory.makeInteraction(className: NSStringFromClass(NSObject.self)) { _ in } == nil)
    }

    @Test("The interaction is built through its update handler initializer and forwards each reading")
    func buildsAndForwards() throws {
        var received: [HingeState?] = []
        let interaction = try #require(HingeInteractionFactory.makeInteraction(
            className: "HAFakeHingeInteraction"
        ) { received.append($0) })
        let fake = try #require(interaction as? FakeHingeInteraction)

        fake.updateHandler(fake, FakeUpdate(hinge: FakeHinge(angle: .pi, status: 3)))
        fake.updateHandler(fake, FakeUpdate(hinge: nil))

        #expect(received.count == 2)
        #expect(received.first??.status == .fullyOpen)
        #expect(received.last == .some(nil))
    }
}
