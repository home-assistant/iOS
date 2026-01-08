import Foundation
import GRDB

// Structure to store camera order per server
struct CameraListConfiguration: Codable, FetchableRecord, PersistableRecord {
    var serverId: String
    // Dictionary: [areaName: [cameraEntityId]]
    var areaOrders: [String: [String]]
    // Array of section names in custom order
    var sectionOrder: [String]?

    init(serverId: String, areaOrders: [String: [String]] = [:], sectionOrder: [String]? = nil) {
        self.serverId = serverId
        self.areaOrders = areaOrders
        self.sectionOrder = sectionOrder
    }
}
