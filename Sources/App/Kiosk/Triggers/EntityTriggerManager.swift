import AVFoundation
import Combine
import Foundation
import Shared
import UIKit

// MARK: - Entity Trigger Manager

/// Manages entity-based triggers that execute actions in response to HA state changes
@MainActor
public final class EntityTriggerManager: ObservableObject {
    // MARK: - Singleton

    public static let shared = EntityTriggerManager()

    // MARK: - Published State

    /// Active triggers being monitored
    @Published public private(set) var activeTriggers: [EntityActionTrigger] = []

    /// Recently fired triggers (for UI feedback)
    @Published public private(set) var recentlyFired: [String] = []

    // MARK: - Callbacks

    /// Called when navigation is triggered
    public var onNavigate: ((String) -> Void)?

    /// Called when screensaver should start
    public var onStartScreensaver: ((ScreensaverMode?) -> Void)?

    /// Called when screensaver should stop
    public var onStopScreensaver: (() -> Void)?

    /// Called when brightness should change
    public var onSetBrightness: ((Float) -> Void)?

    /// Called when refresh is triggered
    public var onRefresh: (() -> Void)?

    /// Called for TTS
    public var onTTS: ((String) -> Void)?

    // MARK: - Private

    private var settings: KioskSettings { KioskModeManager.shared.settings }
    private var entityObservation: AnyCancellable?
    private var previousStates: [String: String] = [:]
    private var pendingReversions: [String: Task<Void, Never>] = [:]
    private var debounceTimers: [String: Timer] = [:]
    private var audioPlayer: AVAudioPlayer?

    // MARK: - Initialization

    private init() {}

    deinit {
        entityObservation?.cancel()
        pendingReversions.values.forEach { $0.cancel() }
        debounceTimers.values.forEach { $0.invalidate() }
        audioPlayer?.stop()
    }

    // MARK: - Public Methods

    /// Start monitoring entity triggers
    public func start() {
        activeTriggers = settings.entityTriggers.filter { $0.enabled }

        let entityIds = Set(activeTriggers.map(\.entityId))
        guard !entityIds.isEmpty else {
            Current.Log.info("No entity triggers configured")
            return
        }

        Current.Log.info("Starting entity trigger monitoring for \(entityIds.count) entities")

        let entityProvider = EntityStateProvider.shared
        entityProvider.watchEntities(Array(entityIds))

        entityObservation = entityProvider.$entityStates
            .sink { [weak self] states in
                self?.evaluateTriggers(states)
            }
    }

    /// Stop monitoring
    public func stop() {
        entityObservation?.cancel()
        entityObservation = nil
        previousStates.removeAll()
        cancelAllPendingReversions()
        cancelAllDebounceTimers()
    }

    /// Reload trigger configuration
    public func reloadConfiguration() {
        stop()
        start()
    }

    /// Manually trigger an action (for testing)
    public func executeAction(_ action: TriggerAction) {
        performAction(action)
    }

    // MARK: - Private Methods

    private func evaluateTriggers(_ states: [String: EntityState]) {
        for trigger in activeTriggers {
            guard let entityState = states[trigger.entityId] else { continue }

            let previousState = previousStates[trigger.entityId]
            let currentState = entityState.state

            // Only fire on state change (not initial load)
            if previousState != nil && previousState != currentState {
                if currentState == trigger.triggerState {
                    handleTriggerMatch(trigger)
                }
            }

            previousStates[trigger.entityId] = currentState
        }
    }

    private func handleTriggerMatch(_ trigger: EntityActionTrigger) {
        // Handle debounce delay
        if trigger.delay > 0 {
            debounceTimers[trigger.id]?.invalidate()
            debounceTimers[trigger.id] = Timer.scheduledTimer(
                withTimeInterval: trigger.delay,
                repeats: false
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.fireTrigger(trigger)
                }
            }
        } else {
            fireTrigger(trigger)
        }
    }

    private func fireTrigger(_ trigger: EntityActionTrigger) {
        Current.Log.info("Firing trigger: \(trigger.entityId) → \(trigger.action)")

        // Track recently fired for UI
        recentlyFired.append(trigger.id)
        Task {
            try? await Task.sleep(nanoseconds: KioskConstants.Timing.recentlyFiredDuration)
            recentlyFired.removeAll { $0 == trigger.id }
        }

        // Execute the action
        performAction(trigger.action)

        // Schedule reversion if duration is set
        if let duration = trigger.duration {
            scheduleReversion(for: trigger, after: duration)
        }
    }

    private func performAction(_ action: TriggerAction) {
        switch action {
        case let .navigate(url):
            onNavigate?(url)

        case let .setBrightness(level):
            onSetBrightness?(level)

        case let .startScreensaver(mode):
            onStartScreensaver?(mode)

        case .stopScreensaver:
            onStopScreensaver?()

        case .refresh:
            onRefresh?()

        case let .playSound(url):
            playSound(from: url)

        case let .tts(message):
            onTTS?(message)
        }
    }

    private func scheduleReversion(for trigger: EntityActionTrigger, after duration: TimeInterval) {
        // Cancel any existing reversion for this trigger
        pendingReversions[trigger.id]?.cancel()

        pendingReversions[trigger.id] = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

            guard !Task.isCancelled else { return }

            // Revert the action
            performReversion(for: trigger.action)
        }
    }

    private func performReversion(for action: TriggerAction) {
        switch action {
        case .navigate:
            // Navigate back to primary dashboard
            DashboardManager.shared.navigateToPrimary()

        case .setBrightness:
            // Restore to manual brightness setting
            onSetBrightness?(settings.manualBrightness)

        case .startScreensaver:
            onStopScreensaver?()

        case .stopScreensaver:
            // Don't auto-restart screensaver
            break

        case .refresh:
            // No reversion needed
            break

        case .playSound:
            // Stop audio
            audioPlayer?.stop()

        case .tts:
            // No reversion needed
            break
        }
    }

    private func playSound(from urlString: String) {
        guard let url = URL(string: urlString) else {
            Current.Log.warning("Invalid sound URL: \(urlString)")
            return
        }

        // Handle local vs remote URLs
        if url.isFileURL {
            playLocalSound(url: url)
        } else {
            Task {
                await playRemoteSound(url: url)
            }
        }
    }

    private func playLocalSound(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            Current.Log.error("Failed to play sound: \(error)")
        }
    }

    private func playRemoteSound(url: URL) async {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            // Validate HTTP response
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                Current.Log.error("Failed to download sound: HTTP \(httpResponse.statusCode)")
                return
            }

            guard !data.isEmpty else {
                Current.Log.error("Downloaded sound data is empty")
                return
            }

            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.play()
        } catch {
            Current.Log.error("Failed to download/play sound: \(error.localizedDescription)")
        }
    }

    private func cancelAllPendingReversions() {
        for task in pendingReversions.values {
            task.cancel()
        }
        pendingReversions.removeAll()
    }

    private func cancelAllDebounceTimers() {
        for timer in debounceTimers.values {
            timer.invalidate()
        }
        debounceTimers.removeAll()
    }
}

// MARK: - Trigger Evaluation Helpers

extension EntityTriggerManager {
    /// Check if any trigger is currently active for an entity
    public func hasActiveTrigger(for entityId: String) -> Bool {
        activeTriggers.contains { $0.entityId == entityId }
    }

    /// Get all triggers for a specific entity
    public func triggers(for entityId: String) -> [EntityActionTrigger] {
        activeTriggers.filter { $0.entityId == entityId }
    }

    /// Check if a trigger recently fired
    public func didRecentlyFire(_ triggerId: String) -> Bool {
        recentlyFired.contains(triggerId)
    }
}

// MARK: - Convenience Triggers

extension EntityTriggerManager {
    /// Create a wake trigger for an entity
    public static func wakeTrigger(entityId: String, state: String) -> EntityActionTrigger {
        EntityActionTrigger(
            entityId: entityId,
            triggerState: state,
            action: .stopScreensaver,
            enabled: true
        )
    }

    /// Create a sleep trigger for an entity
    public static func sleepTrigger(entityId: String, state: String, mode: ScreensaverMode = .blank) -> EntityActionTrigger {
        EntityActionTrigger(
            entityId: entityId,
            triggerState: state,
            action: .startScreensaver(mode: mode),
            enabled: true
        )
    }

    /// Create a navigation trigger for an entity
    public static func navigationTrigger(entityId: String, state: String, url: String, duration: TimeInterval? = nil) -> EntityActionTrigger {
        EntityActionTrigger(
            entityId: entityId,
            triggerState: state,
            action: .navigate(url: url),
            duration: duration,
            enabled: true
        )
    }
}
