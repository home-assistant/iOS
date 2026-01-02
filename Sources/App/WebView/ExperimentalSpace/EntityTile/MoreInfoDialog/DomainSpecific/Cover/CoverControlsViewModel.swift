import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
@Observable
final class CoverControlsViewModel {
    // MARK: - Published State

    var currentPosition: Double = 0 // 0-100
    var isUpdating: Bool = false
    var deviceClass: DeviceClass = .unknown
    var supportsTilt: Bool = false
    var currentTilt: Double = 0 // 0-100
    var isOpening: Bool = false
    var isClosing: Bool = false

    // MARK: - Dependencies

    private let server: Server
    private let appEntity: HAAppEntity
    private var haEntity: HAEntity?

    // MARK: - Initialization

    init(server: Server, appEntity: HAAppEntity, haEntity: HAEntity?) {
        self.server = server
        self.appEntity = appEntity
        self.haEntity = haEntity
    }

    // MARK: - Public Methods

    func updateEntity(_ haEntity: HAEntity?) {
        self.haEntity = haEntity
        updateStateFromEntity()
    }

    func initialize() {
        updateStateFromEntity()
    }

    func stateDescription() -> String {
        guard let haEntity else { return CoreStrings.commonStateOff }

        // If we have a position, show it
        if let position = haEntity.attributes["current_position"] as? Int {
            return "\(position)%"
        }

        return Domain(entityId: appEntity.entityId)?.contextualStateDescription(for: haEntity) ?? haEntity.state
    }

    var coverIcon: SFSymbol {
        switch deviceClass {
        case .blind, .shade:
            return .blindsVerticalClosed
        case .curtain:
            return .curtainsClosed
        case .damper:
            return .fanDesk
        case .door:
            return .doorLeftHandClosed
        case .garage:
            return .doorGarageClosed
        case .gate:
            return .figureWalk
        case .shutter:
            return .squareGrid2x2
        case .window:
            return .windowAwningClosed
        default:
            return .squareGrid2x2
        }
    }

    // MARK: - State Management

    func updateStateFromEntity() {
        guard let haEntity else {
            currentPosition = 0
            deviceClass = .unknown
            supportsTilt = false
            currentTilt = 0
            isOpening = false
            isClosing = false
            return
        }

        // Get position (0-100)
        if let position = haEntity.attributes["current_position"] as? Int {
            currentPosition = Double(position)
        } else {
            // If no position attribute, infer from state
            let state = haEntity.state
            if state == Domain.State.open.rawValue {
                currentPosition = 100
            } else if state == Domain.State.closed.rawValue {
                currentPosition = 0
            }
        }

        // Get tilt if supported
        if let tiltPosition = haEntity.attributes["current_tilt_position"] as? Int {
            supportsTilt = true
            currentTilt = Double(tiltPosition)
        } else {
            supportsTilt = false
            currentTilt = 0
        }

        // Get device class from appEntity (which properly parses it)
        deviceClass = appEntity.deviceClass

        // Check if currently moving
        let state = haEntity.state
        isOpening = state == Domain.State.opening.rawValue
        isClosing = state == Domain.State.closing.rawValue
    }

    // MARK: - Actions

    @MainActor
    func setCoverPosition(_ position: Double) async {
        guard !isUpdating else { return }

        isUpdating = true
        defer { isUpdating = false }

        let intentCover = IntentCoverEntity(
            id: "\(server.identifier.rawValue)-\(appEntity.entityId)",
            entityId: appEntity.entityId,
            serverId: server.identifier.rawValue,
            displayString: appEntity.name,
            iconName: appEntity.icon ?? "blinds.vertical.open"
        )

        let intent = SetCoverPositionIntent()
        intent.cover = intentCover
        intent.position = Int(position)

        do {
            _ = try await intent.perform()
            // Optimistically update state
            currentPosition = position
            Current.Log.info("Successfully set cover position for \(appEntity.entityId) to \(Int(position))%")
        } catch {
            Current.Log.error("Failed to set cover position: \(error)")
        }
    }

    @MainActor
    func openCover() async {
        guard !isUpdating else { return }

        isUpdating = true
        defer { isUpdating = false }

        let intentCover = IntentCoverEntity(
            id: "\(server.identifier.rawValue)-\(appEntity.entityId)",
            entityId: appEntity.entityId,
            serverId: server.identifier.rawValue,
            displayString: appEntity.name,
            iconName: appEntity.icon ?? "blinds.vertical.open"
        )

        let intent = OpenCoverIntent()
        intent.cover = intentCover

        do {
            _ = try await intent.perform()
            // Optimistically update state
            currentPosition = 100
            isOpening = true
            Current.Log.info("Successfully opened cover \(appEntity.entityId)")
        } catch {
            Current.Log.error("Failed to open cover: \(error)")
        }
    }

    @MainActor
    func closeCover() async {
        guard !isUpdating else { return }

        isUpdating = true
        defer { isUpdating = false }

        let intentCover = IntentCoverEntity(
            id: "\(server.identifier.rawValue)-\(appEntity.entityId)",
            entityId: appEntity.entityId,
            serverId: server.identifier.rawValue,
            displayString: appEntity.name,
            iconName: appEntity.icon ?? "blinds.vertical.open"
        )

        let intent = CloseCoverIntent()
        intent.cover = intentCover

        do {
            _ = try await intent.perform()
            // Optimistically update state
            currentPosition = 0
            isClosing = true
            Current.Log.info("Successfully closed cover \(appEntity.entityId)")
        } catch {
            Current.Log.error("Failed to close cover: \(error)")
        }
    }

    @MainActor
    func stopCover() async {
        guard !isUpdating else { return }

        isUpdating = true
        defer { isUpdating = false }

        let intentCover = IntentCoverEntity(
            id: "\(server.identifier.rawValue)-\(appEntity.entityId)",
            entityId: appEntity.entityId,
            serverId: server.identifier.rawValue,
            displayString: appEntity.name,
            iconName: appEntity.icon ?? "blinds.vertical.open"
        )

        let intent = StopCoverIntent()
        intent.cover = intentCover

        do {
            _ = try await intent.perform()
            isOpening = false
            isClosing = false
            Current.Log.info("Successfully stopped cover \(appEntity.entityId)")
        } catch {
            Current.Log.error("Failed to stop cover: \(error)")
        }
    }
}
