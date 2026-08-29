#if !os(watchOS)
import Foundation
import SwiftUI

/// One line of an ``HAEnergySourcesTable``: a single meter, already formatted.
///
/// Energy and cost arrive as strings because how a figure is rounded and which currency symbol it
/// carries are the app's business — the package only lays them out.
///
/// Frontend counterpart: the rows `hui-energy-sources-table-card` builds from its statistics, rather
/// than an element of its own.
public struct HAEnergySourceRow: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let color: Color
    public let energy: String
    public let cost: String?

    public init(id: String, name: String, color: Color = .haPrimary, energy: String, cost: String? = nil) {
        self.id = id
        self.name = name
        self.color = color
        self.energy = energy
        self.cost = cost
    }
}

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
}

#endif
