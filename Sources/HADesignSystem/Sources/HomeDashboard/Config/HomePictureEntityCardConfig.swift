import Foundation

/// A camera, shown as its picture. The area strategy swaps a camera's tile for one of these so a
/// room with a camera in it shows what the camera sees.
public struct HomePictureEntityCardConfig: Equatable, Sendable {
    public let entityId: String
    public let name: String?
    public let tapAction: HomeDashboardAction?

    public init(entityId: String, name: String? = nil, tapAction: HomeDashboardAction? = nil) {
        self.entityId = entityId
        self.name = name
        self.tapAction = tapAction
    }
}
