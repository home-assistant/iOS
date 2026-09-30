import Foundation
import HAKit
import Shared

public struct MenuManagerTitleSubscription: Equatable {
    private var uuid = UUID()
    var server: Server
    var template: String
    var token: HACancellable

    init(server: Server, template: String, token: HACancellable) {
        self.server = server
        self.template = template
        self.token = token
    }

    func cancel() {
        token.cancel()
    }

    public static func == (lhs: MenuManagerTitleSubscription, rhs: MenuManagerTitleSubscription) -> Bool {
        lhs.uuid == rhs.uuid
    }
}
