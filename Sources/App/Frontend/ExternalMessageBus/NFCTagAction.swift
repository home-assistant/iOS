import Foundation
@preconcurrency import Shared

/// Action that writes the entity's deep link straight onto an NFC tag, so that scanning the tag
/// opens the entity's more info dialog. It is the `DeeplinkAction` link, stored on a physical tag
/// instead of being copied to the clipboard.
struct NFCTagAction: EntityAddToAction {
    var mdiIcon: String { "mdi:nfc-variant" }
    var actionType: String { EntityAddToActionType.nfcTag.rawValue }

    func text() -> String {
        L10n.WebView.AddTo.Option.NfcTag.title
    }
}
