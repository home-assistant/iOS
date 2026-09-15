import AppIntents
import Foundation
import Shared

/// Donates the App Intent matching a control the user made in the frontend, so Siri and Spotlight
/// learn which actions they take and can suggest them at the moments they usually happen.
///
/// The system donates only the intents it runs itself; a tap in the web view is invisible to it
/// until the app says what happened. Only what a spoken command could do is donated: a control
/// the intents have no command for would be suggested as something the user cannot then run.
struct EntityControlDonation {
    /// The command an intent exists for, which decides the intent to donate.
    enum Command: Equatable {
        case turnOnOff(TurnOnOffActionAppEnum)
        case openClose(OpenCloseActionAppEnum)
        case lock
    }

    /// Hands a built intent to the system. Tests replace it, having no system to donate to.
    private let donateIntent: (any AppIntent) async throws -> Void

    init(donateIntent: @escaping (any AppIntent) async throws -> Void = { intent in
        _ = try await IntentDonationManager.shared.donate(intent: intent)
    }) {
        self.donateIntent = donateIntent
    }

    /// Donates one intent per entity the call reached, skipping servers hidden from Siri and
    /// entities that resolve to no command or that Siri is not exposed to.
    func donate(_ message: EntityControlMessage, serverId: String) async {
        guard SiriServerExposure.isExposed(serverId: serverId) else { return }
        for entityId in message.entityIds {
            guard let command = Self.command(entityId: entityId, domain: message.domain, service: message.service),
                  let intent = await intent(for: command, entityId: entityId, serverId: serverId) else {
                continue
            }
            do {
                try await donateIntent(intent)
            } catch {
                Current.Log.error("Failed to donate \(type(of: intent)): \(error.localizedDescription)")
            }
        }
    }

    /// The command `service` stands for when called on `entityId`, or nothing when no intent runs it.
    ///
    /// The service is read against the entity's own domain, so `homeassistant.turn_on` on a light is
    /// the same command as `light.turn_on`. Unlocking is left out on purpose, the way the lock intent
    /// leaves it out: a door should never open from a suggestion.
    static func command(entityId: String, domain: String, service: String) -> Command? {
        guard let entityDomain = Domain(entityId: entityId),
              domain == entityDomain.serviceDomain || domain == "homeassistant" else {
            return nil
        }
        if entityDomain == .lock {
            return service == Service.lock.rawValue ? .lock : nil
        }
        guard Domain.voiceControllable.contains(entityDomain), let services = entityDomain.toggleServices else {
            return nil
        }
        if Domain.voiceOpenable.contains(entityDomain) {
            switch service {
            case services.on.rawValue: return .openClose(.open)
            case services.off.rawValue: return .openClose(.close)
            default: return nil
            }
        }
        switch service {
        case services.on.rawValue: return .turnOnOff(.on)
        case services.off.rawValue: return entityDomain.isVoiceSwitchable ? .turnOnOff(.off) : nil
        case Service.toggle.rawValue: return entityDomain.isVoiceSwitchable ? .turnOnOff(.toggle) : nil
        default: return nil
        }
    }

    /// Builds the intent through the very query its entity parameter uses, so nothing is donated that
    /// the system could not resolve when it suggests it back.
    private func intent(for command: Command, entityId: String, serverId: String) async -> (any AppIntent)? {
        let id = ServerEntity.uniqueId(serverId: serverId, entityId: entityId)
        switch command {
        case let .turnOnOff(action):
            guard let entity = try? await HAAppEntityAppIntentEntityQuery().entities(for: [id]).first else { return nil }
            var intent = TurnOnOffEntityAppIntent(action: action)
            intent.entity = entity
            return intent
        case let .openClose(action):
            guard let entity = try? await OpenableEntityAppEntityQuery().entities(for: [id]).first else { return nil }
            var intent = OpenCloseEntityAppIntent(action: action)
            intent.entity = entity
            return intent
        case .lock:
            guard let entity = try? await LockAppEntityQuery().entities(for: [id]).first else { return nil }
            var intent = LockEntityAppIntent()
            intent.entity = entity
            return intent
        }
    }
}
