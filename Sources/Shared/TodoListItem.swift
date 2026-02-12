import Foundation
import HAKit

public struct TodoListItem: HADataDecodable {
    public let summary: String
    public let uid: String
    public let status: String
    public let description: String?

    public init(data: HAData) throws {
        self.summary = try data.decode("summary")
        self.uid = try data.decode("uid")
        self.status = try data.decode("status")
        self.description = data.decode("description") as String?
    }

    public init(summary: String, uid: String, status: String, description: String?) {
        self.summary = summary
        self.uid = uid
        self.status = status
        self.description = description
    }
}

public struct TodoListService: HADataDecodable {
    public let items: [TodoListItem]

    public init(data: HAData) throws {
        self.items = try data.decode("items")
    }
}

public struct TodoListRawResponse: HADataDecodable {
    public let changedStates: [String]
    public let serviceResponse: [String: TodoListService]

    public init(data: HAData) throws {
        self.changedStates = try data.decode("changed_states")
        self.serviceResponse = try data.decode("service_response")
    }
}
