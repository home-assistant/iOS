import Combine
import Foundation
import Shared

// MARK: - Dashboard Manager

/// Manages multiple dashboards with rotation, scheduling, and conditional display
@MainActor
public final class DashboardManager: ObservableObject {
    // MARK: - Singleton

    public static let shared = DashboardManager()

    // MARK: - Published State

    /// Currently active dashboard
    @Published public private(set) var currentDashboard: DashboardConfig?

    /// Index in rotation sequence
    @Published public private(set) var currentRotationIndex: Int = 0

    /// Whether rotation is currently paused (e.g., user touch)
    @Published public private(set) var isRotationPaused: Bool = false

    /// Dashboards available for rotation
    @Published public private(set) var rotationDashboards: [DashboardConfig] = []

    // MARK: - Callbacks

    /// Called when dashboard should change
    public var onNavigate: ((String) -> Void)?

    // MARK: - Private

    private var settings: KioskSettings { KioskModeManager.shared.settings }
    private var rotationTimer: Timer?
    private var pauseResumeTimer: Timer?
    private var scheduleTimer: Timer?
    private var entityObservation: AnyCancellable?
    private var lastActivityTime: Date = Date()

    // MARK: - Initialization

    private init() {
        // Don't start timers in init - wait for start()
    }

    deinit {
        rotationTimer?.invalidate()
        scheduleTimer?.invalidate()
        entityObservation?.cancel()
    }

    // MARK: - Public Methods

    /// Start dashboard management
    public func start() {
        updateRotationDashboards()

        // Check if a schedule entry should override, otherwise navigate to primary
        let scheduledDashboard = checkScheduleAndNavigate()

        // If no schedule matched, navigate to the primary dashboard
        if !scheduledDashboard {
            navigateToPrimary()
        }

        startRotationIfEnabled()
        setupEntityObservation()
        setupScheduleTimer() // Start schedule timer when manager starts
    }

    /// Stop dashboard management
    public func stop() {
        stopRotation()
        scheduleTimer?.invalidate()
        scheduleTimer = nil
        entityObservation?.cancel()
        entityObservation = nil
    }

    /// Navigate to a specific dashboard
    public func navigateTo(_ dashboard: DashboardConfig) {
        currentDashboard = dashboard
        let url = applyKioskParameter(to: dashboard.url)
        onNavigate?(url)
        Current.Log.info("Navigated to dashboard: \(dashboard.name)")
    }

    /// Navigate to dashboard by ID
    public func navigateTo(dashboardId: String) {
        guard let dashboard = settings.dashboards.first(where: { $0.id == dashboardId }) else {
            Current.Log.warning("Dashboard not found: \(dashboardId)")
            return
        }
        navigateTo(dashboard)
    }

    /// Navigate to dashboard by URL
    public func navigateTo(url: String) {
        if let dashboard = settings.dashboards.first(where: { $0.url == url }) {
            navigateTo(dashboard)
        } else {
            // Create an ad-hoc dashboard config
            let adhoc = DashboardConfig(name: "Custom", url: url)
            currentDashboard = adhoc
            let finalURL = applyKioskParameter(to: url)
            onNavigate?(finalURL)
        }
    }

    /// Move to next dashboard in rotation
    public func nextDashboard() {
        guard !rotationDashboards.isEmpty else { return }
        currentRotationIndex = (currentRotationIndex + 1) % rotationDashboards.count
        navigateTo(rotationDashboards[currentRotationIndex])
    }

    /// Move to previous dashboard in rotation
    public func previousDashboard() {
        guard !rotationDashboards.isEmpty else { return }
        currentRotationIndex = (currentRotationIndex - 1 + rotationDashboards.count) % rotationDashboards.count
        navigateTo(rotationDashboards[currentRotationIndex])
    }

    /// Called when user interacts with screen
    public func userActivity() {
        lastActivityTime = Date()

        if settings.pauseRotationOnTouch && settings.rotationEnabled {
            pauseRotation()
        }
    }

    /// Pause rotation temporarily
    public func pauseRotation() {
        guard !isRotationPaused else { return }

        isRotationPaused = true
        rotationTimer?.invalidate()
        rotationTimer = nil

        Current.Log.info("Dashboard rotation paused")

        // Schedule resume after idle timeout
        pauseResumeTimer?.invalidate()
        pauseResumeTimer = Timer.scheduledTimer(
            withTimeInterval: settings.resumeRotationAfterIdle,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resumeRotation()
            }
        }
    }

    /// Resume rotation
    public func resumeRotation() {
        guard isRotationPaused else { return }

        isRotationPaused = false
        pauseResumeTimer?.invalidate()
        pauseResumeTimer = nil

        if settings.rotationEnabled {
            startRotationTimer()
            Current.Log.info("Dashboard rotation resumed")
        }
    }

    /// Reload dashboard configuration
    public func reloadConfiguration() {
        updateRotationDashboards()

        // If current dashboard was removed, navigate to first available
        if let current = currentDashboard,
           !settings.dashboards.contains(where: { $0.id == current.id }) {
            if let first = rotationDashboards.first {
                navigateTo(first)
            }
        }
    }

    // MARK: - Private Methods

    private func updateRotationDashboards() {
        rotationDashboards = settings.dashboards.filter { $0.includeInRotation }

        // Reset index if out of bounds
        if currentRotationIndex >= rotationDashboards.count {
            currentRotationIndex = 0
        }
    }

    private func startRotationIfEnabled() {
        guard settings.rotationEnabled else { return }
        startRotationTimer()
    }

    private func startRotationTimer() {
        rotationTimer?.invalidate()

        guard settings.rotationInterval > 0 else { return }

        rotationTimer = Timer.scheduledTimer(
            withTimeInterval: settings.rotationInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.nextDashboard()
            }
        }
    }

    private func stopRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        pauseResumeTimer?.invalidate()
        pauseResumeTimer = nil
        isRotationPaused = false
    }

    // MARK: - Schedule Management

    private func setupScheduleTimer() {
        // Check schedule every minute
        scheduleTimer = Timer.scheduledTimer(
            withTimeInterval: 60,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkSchedule()
            }
        }
    }

    /// Check schedule and navigate if a matching entry is found
    /// - Returns: true if a scheduled dashboard was navigated to, false otherwise
    @discardableResult
    private func checkScheduleAndNavigate() -> Bool {
        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)

        // Find matching schedule entry
        for entry in settings.dashboardSchedule {
            guard entry.daysOfWeek.contains(weekday) else { continue }

            let currentTime = TimeOfDay(hour: hour, minute: minute)

            if isTimeInRange(currentTime, start: entry.startTime, end: entry.endTime) {
                // Found a matching schedule - navigate to that dashboard
                if currentDashboard?.id != entry.dashboardId {
                    navigateTo(dashboardId: entry.dashboardId)
                }
                return true
            }
        }
        return false
    }

    /// Check schedule (for timer-based periodic checks)
    private func checkSchedule() {
        _ = checkScheduleAndNavigate()
    }

    private func isTimeInRange(_ time: TimeOfDay, start: TimeOfDay, end: TimeOfDay) -> Bool {
        if start.isBefore(end) {
            // Normal range (e.g., 08:00 to 17:00)
            return !time.isBefore(start) && time.isBefore(end)
        } else {
            // Overnight range (e.g., 22:00 to 06:00)
            return !time.isBefore(start) || time.isBefore(end)
        }
    }

    // MARK: - Entity-Based Dashboard Switching

    private func setupEntityObservation() {
        // Watch entities that can trigger dashboard changes
        let entityProvider = EntityStateProvider.shared

        // Collect all entity IDs that affect dashboard selection
        let triggerEntityIds = settings.entityTriggers
            .filter { trigger in
                if case .navigate = trigger.action {
                    return true
                }
                return false
            }
            .map(\.entityId)

        guard !triggerEntityIds.isEmpty else { return }

        entityProvider.watchEntities(triggerEntityIds)

        entityObservation = entityProvider.$entityStates
            .sink { [weak self] states in
                self?.evaluateEntityConditions(states)
            }
    }

    private func evaluateEntityConditions(_ states: [String: EntityState]) {
        for trigger in settings.entityTriggers where trigger.enabled {
            guard let entityState = states[trigger.entityId] else { continue }

            if entityState.state == trigger.triggerState {
                if case let .navigate(url) = trigger.action {
                    navigateTo(url: url)
                }
            }
        }
    }
}

// MARK: - Dashboard Helpers

extension DashboardManager {
    /// Get the primary dashboard URL
    public var primaryDashboardURL: String? {
        if !settings.primaryDashboardURL.isEmpty {
            return settings.primaryDashboardURL
        }
        return settings.dashboards.first?.url
    }

    /// Navigate to the primary dashboard
    public func navigateToPrimary() {
        if let url = primaryDashboardURL {
            navigateTo(url: url)
        }
    }

    /// Check if a dashboard exists
    public func dashboardExists(id: String) -> Bool {
        settings.dashboards.contains { $0.id == id }
    }

    /// Get dashboard by ID
    public func getDashboard(id: String) -> DashboardConfig? {
        settings.dashboards.first { $0.id == id }
    }

    /// Apply kiosk parameter to URL if enabled
    /// Appends ?kiosk or &kiosk to the URL for the kiosk-mode HACS integration
    public func applyKioskParameter(to url: String) -> String {
        guard settings.appendKioskParameter else { return url }

        // Don't add if already present
        if url.contains("kiosk") { return url }

        if url.contains("?") {
            return "\(url)&kiosk"
        } else {
            return "\(url)?kiosk"
        }
    }
}
