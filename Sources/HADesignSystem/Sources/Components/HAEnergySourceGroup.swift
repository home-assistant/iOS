#if !os(watchOS)
import Foundation
import SwiftUI

/// A kind of source — solar, grid, battery, gas, water — and its meters, mirroring how
/// `hui-energy-sources-table-card` groups its rows and totals each group.
public struct HAEnergySourceGroup: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let rows: [HAEnergySourceRow]
    public let totalEnergy: String
    public let totalCost: String?

    public init(
        id: String,
        title: String,
        rows: [HAEnergySourceRow],
        totalEnergy: String,
        totalCost: String? = nil
    ) {
        self.id = id
        self.title = title
        self.rows = rows
        self.totalEnergy = totalEnergy
        self.totalCost = totalCost
    }
}

extension HAEnergySourceGroup: FrontendComponent {
    public static var frontendComponentName: String { "hui-energy-sources-table-card" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
