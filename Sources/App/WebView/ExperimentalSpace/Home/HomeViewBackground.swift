import Foundation
import SwiftUI

/// Background type for HomeView
enum HomeViewBackgroundType: String, Codable, CaseIterable {
    case image
    case view
}

/// Background option for HomeView
struct HomeViewBackgroundOption: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let type: HomeViewBackgroundType

    static let allOptions: [HomeViewBackgroundOption] = [
        .init(id: "gradient1", name: "Ocean Blue", type: .view),
        .init(id: "gradient2", name: "Sky Dreams", type: .view),
        .init(id: "gradient3", name: "Deep Sea", type: .view),
        .init(id: "gradient4", name: "Azure Wave", type: .view),
        .init(id: "gradient5", name: "Midnight Blue", type: .view),
        .init(id: "gradient6", name: "Crystal Waters", type: .view),
        .init(id: "gradient7", name: "Electric Blue", type: .view),
        .init(id: "gradient8", name: "Sapphire Glow", type: .view),
        .init(id: "gradient9", name: "Arctic Flow", type: .view),
        .init(id: "gradient10", name: "Blue Horizon", type: .view),
    ]

    static let defaultOption = allOptions[0]
}

@available(iOS 18.0, *)
struct HomeViewBackgroundView: View {
    let backgroundId: String

    var body: some View {
        switch backgroundId {
        case "gradient1":
            oceanBlueGradient
        case "gradient2":
            skyDreamsGradient
        case "gradient3":
            deepSeaGradient
        case "gradient4":
            azureWaveGradient
        case "gradient5":
            midnightBlueGradient
        case "gradient6":
            crystalWatersGradient
        case "gradient7":
            electricBlueGradient
        case "gradient8":
            sapphireGlowGradient
        case "gradient9":
            arcticFlowGradient
        case "gradient10":
            blueHorizonGradient
        default:
            oceanBlueGradient
        }
    }

    // MARK: - Gradient Backgrounds

    private var oceanBlueGradient: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
            ],
            colors: [
                .blue20, .blue30, .blue40,
                .blue30, .blue50, .blue60,
                .blue40, .blue60, .blue70,
            ]
        )
        .ignoresSafeArea()
    }

    private var skyDreamsGradient: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
            ],
            colors: [
                .blue70, .blue80, .blue90,
                .blue60, .blue70, .blue80,
                .blue50, .blue60, .blue70,
            ]
        )
        .ignoresSafeArea()
    }

    private var deepSeaGradient: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
            ],
            colors: [
                .blue05, .blue10, .blue20,
                .blue10, .blue20, .blue30,
                .blue20, .blue30, .blue40,
            ]
        )
        .ignoresSafeArea()
    }

    private var azureWaveGradient: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.3, 0.5], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
            ],
            colors: [
                .blue40, .blue50, .blue60,
                .blue50, .blue60, .blue70,
                .blue60, .blue70, .blue80,
            ]
        )
        .ignoresSafeArea()
    }

    private var midnightBlueGradient: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
            ],
            colors: [
                .blue05, .indigo10, .blue10,
                .indigo10, .blue20, .indigo20,
                .blue10, .indigo20, .blue30,
            ]
        )
        .ignoresSafeArea()
    }

    private var crystalWatersGradient: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
            ],
            colors: [
                .cyan50, .blue60, .cyan60,
                .blue60, .cyan70, .blue70,
                .cyan60, .blue70, .cyan80,
            ]
        )
        .ignoresSafeArea()
    }

    private var electricBlueGradient: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
            ],
            colors: [
                .blue60, .indigo60, .blue70,
                .indigo60, .blue70, .indigo70,
                .blue70, .indigo70, .blue80,
            ]
        )
        .ignoresSafeArea()
    }

    private var sapphireGlowGradient: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.7, 0.5], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
            ],
            colors: [
                .blue30, .blue40, .blue50,
                .blue40, .indigo50, .blue60,
                .blue50, .blue60, .indigo60,
            ]
        )
        .ignoresSafeArea()
    }

    private var arcticFlowGradient: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
            ],
            colors: [
                .blue80, .cyan80, .blue90,
                .cyan80, .blue90, .cyan90,
                .blue90, .cyan90, .blue95,
            ]
        )
        .ignoresSafeArea()
    }

    private var blueHorizonGradient: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.5, 0.6], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
            ],
            colors: [
                .blue50, .blue60, .cyan60,
                .blue60, .cyan70, .blue70,
                .cyan70, .blue80, .cyan80,
            ]
        )
        .ignoresSafeArea()
    }
}
