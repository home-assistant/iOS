import Foundation
import Shared
import UIKit

enum HingeInteractionFactory {
    @objc private protocol UpdateHandlerInitializable {
        init(updateHandler: @escaping (NSObject, NSObject) -> Void)
    }

    static let interactionClassName = "UIHingeInteraction"
    private static let initializerSelector = NSSelectorFromString("initWithUpdateHandler:")

    static func makeInteraction(
        className: String = interactionClassName,
        onUpdate: @escaping (HingeState?) -> Void
    ) -> UIInteraction? {
        guard let interactionClass = NSClassFromString(className) as? NSObject.Type,
              interactionClass.instancesRespond(to: initializerSelector) else {
            return nil
        }
        let initializable = unsafeBitCast(interactionClass, to: UpdateHandlerInitializable.Type.self)
        let interaction = initializable.init(updateHandler: { _, update in
            onUpdate(state(from: update))
        })
        return interaction as? UIInteraction
    }

    static func state(from update: NSObject) -> HingeState? {
        guard update.responds(to: NSSelectorFromString("hinge")),
              let hinge = update.value(forKey: "hinge") as? NSObject,
              hinge.responds(to: NSSelectorFromString("angle")),
              hinge.responds(to: NSSelectorFromString("status")),
              let angle = hinge.value(forKey: "angle") as? NSNumber,
              let status = hinge.value(forKey: "status") as? NSNumber else {
            return nil
        }
        return HingeState(angleRadians: angle.doubleValue, uiKitStatusRawValue: status.intValue)
    }
}
