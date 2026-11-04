import Foundation
import Shared
import SwiftUI
import UIKit

final class DeeplinkViewModel: ObservableObject {
    let target: DeeplinkTarget
    let serverName: String

    @Published var includeServer = false
    @Published var didCopy = false

    private var resetWorkItem: DispatchWorkItem?

    init(target: DeeplinkTarget, serverName: String) {
        self.target = target
        self.serverName = serverName
    }

    var hasMultipleServers: Bool {
        Current.servers.all.count > 1
    }

    var description: String {
        target.localizedDescription
    }

    var deeplink: String {
        target.url(serverName: includeServer ? serverName : nil)?.absoluteString ?? ""
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: workItem)
    }

    func includeServerChanged() {
        resetWorkItem?.cancel()
        withAnimation { didCopy = false }
    }
}
