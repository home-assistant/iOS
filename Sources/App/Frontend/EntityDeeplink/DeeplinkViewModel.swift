import Foundation
import Shared
import SwiftUI
import UIKit

final class DeeplinkViewModel: ObservableObject {
    let entityId: String
    let serverName: String

    @Published var includeServer = false
    @Published var didCopy = false

    private var resetWorkItem: DispatchWorkItem?

    init(entityId: String, serverName: String) {
        self.entityId = entityId
        self.serverName = serverName
    }

    var hasMultipleServers: Bool {
        Current.servers.all.count > 1
    }

    var deeplink: String {
        let url = includeServer
            ? AppConstants.openEntityMoreInfoDeeplinkURL(entityId: entityId, serverName: serverName)
            : AppConstants.openEntityMoreInfoDeeplinkURL(entityId: entityId)
        return url?.absoluteString ?? ""
    }

    func copyToClipboard() {
        UIPasteboard.general.string = deeplink
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        resetWorkItem?.cancel()
        withAnimation { didCopy = true }
        let workItem = DispatchWorkItem { [weak self] in
            withAnimation { self?.didCopy = false }
        }
        resetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }

    func includeServerChanged() {
        resetWorkItem?.cancel()
        withAnimation { didCopy = false }
    }
}
