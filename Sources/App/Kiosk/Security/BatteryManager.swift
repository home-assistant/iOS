import Combine
import Shared
import UIKit

// MARK: - Battery Manager

/// Monitors battery status and thermal state for wall-mounted displays
@MainActor
public final class BatteryManager: ObservableObject {
    // MARK: - Singleton

    public static let shared = BatteryManager()

    // MARK: - Published Properties

    @Published public private(set) var batteryLevel: Float = 1.0
    @Published public private(set) var batteryState: UIDevice.BatteryState = .unknown
    @Published public private(set) var isLowPowerModeEnabled = false
    @Published public private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    @Published public private(set) var isCharging = false
    @Published public private(set) var lastLowBatteryWarning: Date?
    @Published public private(set) var lastThermalWarning: Date?

    // MARK: - Private Properties

    private var settings: KioskSettings { KioskModeManager.shared.settings }
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Constants

    private let lowBatteryDebounceInterval: TimeInterval = 300  // 5 minutes
    private let thermalThrottlingDebounceInterval: TimeInterval = 60  // 1 minute
    private let batteryHealthDegradationThreshold: Float = 0.2

    // MARK: - Initialization

    private init() {
        setupBatteryMonitoring()
        setupThermalMonitoring()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Battery Monitoring Setup

    private func setupBatteryMonitoring() {
        // Enable battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true

        // Get initial values
        updateBatteryStatus()

        // Observe battery level changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelDidChange),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )

        // Observe battery state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateDidChange),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )

        // Observe low power mode changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(lowPowerModeDidChange),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }

    private func setupThermalMonitoring() {
        // Get initial thermal state
        updateThermalState()

        // Observe thermal state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateDidChange),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
    }

    // MARK: - Battery Status

    @objc private func batteryLevelDidChange() {
        updateBatteryStatus()
        checkLowBatteryWarning()
    }

    @objc private func batteryStateDidChange() {
        updateBatteryStatus()
    }

    @objc private func lowPowerModeDidChange() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        Current.Log.info("Low Power Mode: \(isLowPowerModeEnabled ? "enabled" : "disabled")")
    }

    private func updateBatteryStatus() {
        batteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
        isCharging = batteryState == .charging || batteryState == .full

        // Notify sensor provider
        NotificationCenter.default.post(name: .batteryStatusChanged, object: nil)
    }

    private func checkLowBatteryWarning() {
        let threshold = settings.lowBatteryAlertThreshold
        guard threshold > 0 else { return }

        let levelPercent = Int(batteryLevel * 100)

        if levelPercent <= threshold && !isCharging {
            // Debounce warnings
            if let lastWarning = lastLowBatteryWarning,
               Date().timeIntervalSince(lastWarning) < lowBatteryDebounceInterval {
                return
            }

            lastLowBatteryWarning = Date()
            triggerLowBatteryWarning(level: levelPercent)
        }
    }

    private func triggerLowBatteryWarning(level: Int) {
        Current.Log.warning("Low battery warning: \(level)%")

        // Play warning sound
        if settings.audioAlertsEnabled {
            TouchFeedbackManager.shared.playFeedback(for: .warning)
        }

        // Notify HA
        NotificationCenter.default.post(
            name: .lowBatteryWarning,
            object: nil,
            userInfo: ["level": level]
        )
    }

    // MARK: - Thermal Monitoring

    @objc private func thermalStateDidChange() {
        updateThermalState()
    }

    private func updateThermalState() {
        thermalState = ProcessInfo.processInfo.thermalState

        // Log state change
        Current.Log.info("Thermal state changed to: \(thermalStateName)")

        // Notify sensor provider
        NotificationCenter.default.post(name: .thermalStateChanged, object: nil)

        // Check for throttling warnings
        checkThermalWarning()
    }

    private func checkThermalWarning() {
        guard settings.thermalThrottlingWarnings else { return }

        switch thermalState {
        case .serious, .critical:
            // Debounce warnings
            if let lastWarning = lastThermalWarning,
               Date().timeIntervalSince(lastWarning) < thermalThrottlingDebounceInterval {
                return
            }

            lastThermalWarning = Date()
            triggerThermalWarning()

        default:
            break
        }
    }

    private func triggerThermalWarning() {
        Current.Log.warning("Thermal throttling warning: \(thermalStateName)")

        // Show alert
        let alert = UIAlertController(
            title: "Device Overheating",
            message: "The device temperature is high. Performance may be reduced. Consider improving ventilation or reducing screen brightness.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Reduce Brightness", style: .default) { _ in
            // Reduce brightness to help cool down
            KioskModeManager.shared.setBrightness(30)
        })

        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))

        // Present alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }

        // Notify HA
        NotificationCenter.default.post(
            name: .thermalWarning,
            object: nil,
            userInfo: ["state": thermalStateName]
        )
    }

    // MARK: - Public Properties

    /// Battery level as percentage (0-100)
    public var batteryPercentage: Int {
        Int(batteryLevel * 100)
    }

    /// Human-readable battery state
    public var batteryStateName: String {
        switch batteryState {
        case .unknown: return "Unknown"
        case .unplugged: return "Unplugged"
        case .charging: return "Charging"
        case .full: return "Full"
        @unknown default: return "Unknown"
        }
    }

    /// Human-readable thermal state
    public var thermalStateName: String {
        switch thermalState {
        case .nominal: return "Normal"
        case .fair: return "Warm"
        case .serious: return "Hot"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    /// Icon for thermal state
    public var thermalStateIcon: String {
        switch thermalState {
        case .nominal: return "thermometer"
        case .fair: return "thermometer.medium"
        case .serious: return "thermometer.high"
        case .critical: return "flame.fill"
        @unknown default: return "thermometer"
        }
    }

    /// Color for thermal state
    public var thermalStateColor: UIColor {
        switch thermalState {
        case .nominal: return .systemGreen
        case .fair: return .systemYellow
        case .serious: return .systemOrange
        case .critical: return .systemRed
        @unknown default: return .systemGray
        }
    }

    // MARK: - Battery Health (Estimated)

    /// Estimate battery health based on available information
    /// Note: iOS doesn't expose actual battery health, this is an approximation
    public var estimatedBatteryHealth: BatteryHealth {
        // If device is charging and battery level is stuck at a low percentage,
        // it might indicate degraded battery
        // This is a rough heuristic - real battery health requires private APIs
        if isCharging && batteryLevel < batteryHealthDegradationThreshold {
            return .degraded
        }
        return .good
    }

    public enum BatteryHealth: String {
        case good = "Good"
        case degraded = "Degraded"
        case unknown = "Unknown"
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let batteryStatusChanged = Notification.Name("batteryStatusChanged")
    static let lowBatteryWarning = Notification.Name("lowBatteryWarning")
    static let thermalStateChanged = Notification.Name("thermalStateChanged")
    static let thermalWarning = Notification.Name("thermalWarning")
}

// MARK: - Battery Settings View

import SwiftUI

public struct BatterySettingsView: View {
    @ObservedObject private var manager = BatteryManager.shared
    @ObservedObject private var kioskManager = KioskModeManager.shared

    public init() {}

    public var body: some View {
        Form {
            Section {
                // Battery level
                HStack {
                    Label("Battery Level", systemImage: batteryIcon)
                        .foregroundColor(batteryColor)
                    Spacer()
                    Text("\(manager.batteryPercentage)%")
                        .foregroundColor(.secondary)
                }

                // Charging status
                HStack {
                    Label("Status", systemImage: manager.isCharging ? "bolt.fill" : "battery.100")
                    Spacer()
                    Text(manager.batteryStateName)
                        .foregroundColor(.secondary)
                }

                // Low power mode
                if manager.isLowPowerModeEnabled {
                    HStack {
                        Label("Low Power Mode", systemImage: "leaf.fill")
                            .foregroundColor(.yellow)
                        Spacer()
                        Text("Enabled")
                            .foregroundColor(.yellow)
                    }
                }

            } header: {
                Text("Battery Status")
            }

            Section {
                // Thermal state
                HStack {
                    Label("Temperature", systemImage: manager.thermalStateIcon)
                        .foregroundColor(Color(manager.thermalStateColor))
                    Spacer()
                    Text(manager.thermalStateName)
                        .foregroundColor(Color(manager.thermalStateColor))
                }

            } header: {
                Text("Thermal Status")
            }

            Section {
                // Low battery threshold
                Stepper(
                    "Low Battery Warning: \(kioskManager.settings.lowBatteryAlertThreshold)%",
                    value: Binding(
                        get: { kioskManager.settings.lowBatteryAlertThreshold },
                        set: { newValue in
                            kioskManager.updateSettings { $0.lowBatteryAlertThreshold = newValue }
                        }
                    ),
                    in: 0...50,
                    step: 5
                )

                Toggle("Thermal Throttling Warnings", isOn: Binding(
                    get: { kioskManager.settings.thermalThrottlingWarnings },
                    set: { newValue in
                        kioskManager.updateSettings { $0.thermalThrottlingWarnings = newValue }
                    }
                ))

                Toggle("Report Battery Health", isOn: Binding(
                    get: { kioskManager.settings.reportBatteryHealth },
                    set: { newValue in
                        kioskManager.updateSettings { $0.reportBatteryHealth = newValue }
                    }
                ))

                Toggle("Report Thermal State", isOn: Binding(
                    get: { kioskManager.settings.reportThermalState },
                    set: { newValue in
                        kioskManager.updateSettings { $0.reportThermalState = newValue }
                    }
                ))

            } header: {
                Text("Alerts & Reporting")
            } footer: {
                Text("Configure warnings for low battery and high temperature conditions. Reports are sent to Home Assistant.")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    tipRow(icon: "sun.max", text: "Keep the device out of direct sunlight")
                    tipRow(icon: "wind", text: "Ensure adequate ventilation behind the mount")
                    tipRow(icon: "moon", text: "Lower brightness at night to reduce heat")
                    tipRow(icon: "bolt.slash", text: "Consider limiting charge to 80% for battery longevity")
                }
                .padding(.vertical, 5)
            } header: {
                Text("Tips for Wall-Mounted Displays")
            }
        }
        .navigationTitle("Battery & Thermal")
    }

    private var batteryIcon: String {
        if manager.isCharging {
            return "battery.100.bolt"
        }

        switch manager.batteryPercentage {
        case 0...25: return "battery.25"
        case 26...50: return "battery.50"
        case 51...75: return "battery.75"
        default: return "battery.100"
        }
    }

    private var batteryColor: Color {
        if manager.batteryPercentage <= 20 && !manager.isCharging {
            return .red
        } else if manager.batteryPercentage <= 40 && !manager.isCharging {
            return .orange
        }
        return .green
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
        }
    }
}
