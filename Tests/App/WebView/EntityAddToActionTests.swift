import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

/// The "Add to" actions the app offers the frontend: how each one describes itself, and that each
/// survives the round trip through the opaque `app_payload` the frontend hands back.
struct EntityAddToActionTests {
    /// Claims a known action type without being that action, which the encoder must refuse.
    private struct ImpostorAction: EntityAddToAction {
        let actionType: String
        var mdiIcon: String { "mdi:help" }
        func text() -> String { "Impostor" }
    }

    private static let actions: [any EntityAddToAction] = [
        CarPlayQuickAccessAction(),
        WatchItemAction(),
        CustomWidgetAction(),
        MacToolbarItemAction(),
        DeeplinkAction(),
        NFCTagAction(),
    ]

    @Test func everyActionDescribesItselfDistinctly() {
        let actions = Self.actions
        #expect(Set(actions.map(\.actionType)).count == actions.count)
        #expect(Set(actions.map(\.mdiIcon)).count == actions.count)
        #expect(actions.allSatisfy { $0.mdiIcon.hasPrefix("mdi:") })
        #expect(actions.allSatisfy { !$0.text().isEmpty })
        let enabledStates = actions.map(\.enabled)
        #expect(!enabledStates.contains(false))
        #expect(actions.allSatisfy { $0.details() == nil })
        #expect(actions.map(\.actionType) == [
            EntityAddToActionType.carPlayQuickAccess,
            .watchItem,
            .customWidget,
            .macToolbarItem,
            .deeplink,
            .nfcTag,
        ].map(\.rawValue))
    }

    @Test func everyActionSurvivesTheRoundTripThroughTheFrontend() throws {
        for action in Self.actions {
            let external = try ExternalEntityAddToAction.from(action: action)
            #expect(external.name == action.text())
            #expect(external.mdiIcon == action.mdiIcon)
            #expect(external.enabled)

            let dictionary = external.toDictionary()
            #expect(dictionary["app_payload"] as? String == external.appPayload)
            #expect(dictionary["name"] as? String == action.text())
            #expect(dictionary["mdi_icon"] as? String == action.mdiIcon)
            #expect(dictionary["enabled"] as? Bool == true)

            let decoded = try ExternalEntityAddToAction.toAction(from: external.appPayload)
            #expect(decoded.actionType == action.actionType)
            #expect(type(of: decoded) == type(of: action))
        }
    }

    @Test func theExternalRepresentationEncodesWithTheFrontendsKeys() throws {
        let external = try ExternalEntityAddToAction.from(action: DeeplinkAction())
        let data = try JSONEncoder().encode(external)
        let jsonValue = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let json = try #require(jsonValue)
        #expect(json["app_payload"] as? String == external.appPayload)
        #expect(json["mdi_icon"] as? String == "mdi:link-variant")

        let decoded = try JSONDecoder().decode(ExternalEntityAddToAction.self, from: data)
        #expect(decoded.appPayload == external.appPayload)
    }

    @Test func aPayloadThatIsNotBase64IsRejected() {
        #expect(throws: EntityAddToError.self) {
            _ = try ExternalEntityAddToAction.toAction(from: "%%% not base64 %%%")
        }
    }

    @Test func aPayloadWithAnUnknownTypeIsRejected() {
        let payload = Data(#"{"type":"teleport","data":{}}"#.utf8).base64EncodedString()
        #expect(throws: (any Error).self) {
            _ = try ExternalEntityAddToAction.toAction(from: payload)
        }
    }

    @Test(arguments: [
        "carPlayQuickAccess",
        "watchItem",
        "customWidget",
        "macToolbarItem",
        "deeplink",
        "nfcTag",
        "unknown",
    ])
    func anActionThatIsNotWhatItClaimsCannotBeEncoded(actionType: String) {
        #expect(throws: (any Error).self) {
            _ = try ExternalEntityAddToAction.from(action: ImpostorAction(actionType: actionType))
        }
    }

    @Test func handlerErrorsMapOntoTheSharedErrorCases() {
        #expect(EntityAddToError.handlerDeallocated == .decodingFailed)
        #expect(EntityAddToError.webViewControllerUnavailable == .decodingFailed)
        #expect(EntityAddToError.unknownActionType == .invalidPayload)
    }
}
