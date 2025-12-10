import CarPlay
import Foundation
import HAKit
import PromiseKit
import Shared

@available(iOS 16.0, *)
final class CarPlayLockConfirmation {
    /// Displays a lock/unlock confirmation dialog appropriate for the entity's current state
    /// - Parameters:
    ///   - entityName: The friendly name of the lock entity
    ///   - currentState: The current state of the lock entity (e.g., "locked", "unlocked")
    ///   - interfaceController: The CarPlay interface controller to present the alert on
    ///   - completion: Closure to execute when the user confirms the action
    static func show(
        entityName: String,
        currentState: String,
        interfaceController: CPInterfaceController?,
        completion: @escaping () -> Void
    ) {
        guard let state = Domain.State(rawValue: currentState) else {
            // If we can't determine the state, show a generic confirmation
            showGenericConfirmation(
                entityName: entityName,
                interfaceController: interfaceController,
                completion: completion
            )
            return
        }
        
        let title: String
        switch state {
        case .locked, .locking:
            title = L10n.CarPlay.Unlock.Confirmation.title(entityName)
        default:
            title = L10n.CarPlay.Lock.Confirmation.title(entityName)
        }

        let alert = CPAlertTemplate(titleVariants: [title], actions: [
            .init(title: L10n.Alerts.Confirm.cancel, style: .cancel, handler: { _ in
                interfaceController?.dismissTemplate(animated: true, completion: nil)
            }),
            .init(title: L10n.Alerts.Confirm.confirm, style: .destructive, handler: { _ in
                completion()
                interfaceController?.dismissTemplate(animated: true, completion: nil)
            }),
        ])

        interfaceController?.presentTemplate(alert, animated: true, completion: nil)
    }
    
    /// Execute a lock entity using entity.onPress approach
    /// This ensures consistent lock/unlock behavior across all CarPlay templates
    /// - Parameters:
    ///   - entityId: The entity ID of the lock
    ///   - currentState: The current state of the lock entity
    ///   - api: The Home Assistant API connection
    ///   - completion: Closure called with success/failure result
    static func execute(
        entityId: String,
        currentState: String,
        api: HomeAssistantAPI,
        completion: @escaping (Bool) -> Void
    ) {
        // Create entity with current state to use with onPress
        guard let entity = try? HAEntity(
            entityId: entityId,
            state: currentState,
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [:],
            context: .init(id: "", userId: "", parentId: "")
        ) else {
            Current.Log.error("Failed to create entity for lock: \(entityId)")
            completion(false)
            return
        }

        // Use entity.onPress to execute, consistent across all templates
        firstly {
            entity.onPress(for: api)
        }.done {
            Current.Log.verbose("Successfully executed lock action for: \(entityId)")
            completion(true)
        }.catch { error in
            Current.Log.error("Received error from callService during lock onPress call: \(error)")
            completion(false)
        }
    }
    
    /// Shows a generic lock confirmation when state cannot be determined
    private static func showGenericConfirmation(
        entityName: String,
        interfaceController: CPInterfaceController?,
        completion: @escaping () -> Void
    ) {
        let title = L10n.CarPlay.Lock.Confirmation.title(entityName)
        
        let alert = CPAlertTemplate(titleVariants: [title], actions: [
            .init(title: L10n.Alerts.Confirm.cancel, style: .cancel, handler: { _ in
                interfaceController?.dismissTemplate(animated: true, completion: nil)
            }),
            .init(title: L10n.Alerts.Confirm.confirm, style: .destructive, handler: { _ in
                completion()
                interfaceController?.dismissTemplate(animated: true, completion: nil)
            }),
        ])

        interfaceController?.presentTemplate(alert, animated: true, completion: nil)
    }
}
