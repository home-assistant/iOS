import CoreLocation
import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// iOS smoke tests: lays out the settings screens that moved to the shared grouped list, so a row that
/// stops building is caught here. What the Mac draws is checked by hand on a Mac.
// Serialized: the tests swap `Current.servers`, which concurrent tests would race on.
@MainActor
@Suite(.serialized)
struct SettingsScreensRenderTests {
    private func withFakeServers(_ body: () throws -> Void) rethrows {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 1)
        try body()
    }

    @Test func greetings() {
        renderInWindow(NavigationView { GreetingsSettingsView() })
    }

    @Test func importExportConfiguration() {
        withFakeServers {
            renderInWindow(NavigationView { ImportExportConfigurationView() })
        }
    }

    @Test func focusHowItWorks() {
        renderInWindow(NavigationView { FocusHowItWorksView() })
    }

    @Test func generalSettingsTemplateEditor() {
        withFakeServers {
            renderInWindow(NavigationView { GeneralSettingsTemplateEditor() })
        }
    }

    @Test func macToolbarSettings() {
        withFakeServers {
            renderInWindow(NavigationView { MacToolbarSettingsView() })
        }
    }

    @Test func assistPromptMagicItem() {
        withFakeServers {
            renderInWindow(NavigationView { AssistPromptMagicItemView(mode: .add) { _ in } })
        }
    }

    @Test func notificationRateLimit() {
        renderInWindow(NavigationView { NotificationRateLimitView() })
    }

    @Test func sensorPermissions() {
        renderInWindow(NavigationView { SensorPermissionsView() })
    }

    @Test func nfcTag() {
        renderInWindow(NavigationView { NFCTagView(identifier: "5f2b7c54-1c8e-4c7a-9f6e-3f1d2a0b8c9d") })
    }

    @Test func notificationDebug() {
        withFakeServers {
            renderInWindow(NavigationView { NotificationDebugView() })
        }
    }

    @Test func yamlPreviewSection() {
        renderInWindow(NavigationView {
            List {
                YamlPreviewSection(header: "Automation", yaml: "alias: Hello\ntrigger: []\n")
            }
        })
    }

    @Test func locationSettings() {
        withFakeServers {
            renderInWindow(NavigationView { LocationSettingsView() })
        }
    }

    /// With a zone on record the screen adds the zone cards, and each one opens on a map.
    @Test func locationSettingsWithAZoneAndItsMap() throws {
        let database = try DatabaseQueue()
        try AppZoneTable().createIfNeeded(database: database)
        let previousDatabase = Current.database
        Current.database = { database }
        defer { Current.database = previousDatabase }

        withFakeServers {
            AppZone(
                entityId: "zone.home",
                serverIdentifier: Current.servers.all[0].identifier.rawValue,
                friendlyName: "Home",
                latitude: 37.7749,
                longitude: -122.4194,
                radius: 100
            ).save()

            renderInWindow(NavigationView { LocationSettingsView() })
            renderInWindow(NavigationView {
                LocationZoneMapView(
                    title: "Home",
                    coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                    radius: 100
                )
            })
        }
    }

    @Test func sensorDetail() {
        withFakeServers {
            let sensor = WebhookSensor(name: "Battery Level", uniqueID: "battery_level")
            renderInWindow(NavigationView { SensorDetailView(sensor: sensor, server: Current.servers.all[0]) })
        }
    }

    /// Every kind of setting a sensor can expose gets a row of its own.
    @Test func sensorDetailWithSettings() {
        withFakeServers {
            var value = 5.0
            var isOn = true
            let sensor = WebhookSensor(name: "Pedometer", uniqueID: "pedometer")
            sensor.Settings = [
                WebhookSensorSetting(type: .switch(getter: { isOn }, setter: { isOn = $0 }), title: "Enabled"),
                WebhookSensorSetting(
                    type: .stepper(getter: { value }, setter: { value = $0 }, displayValueFor: { "\($0 ?? 0)" }),
                    title: "Steps"
                ),
                WebhookSensorSetting(
                    type: .slider(getter: { value }, setter: { value = $0 }, displayValueFor: nil),
                    title: "Slider"
                ),
            ]
            renderInWindow(NavigationView { SensorDetailView(sensor: sensor, server: Current.servers.all[0]) })
        }
    }

    /// CarPlay and app icon shortcuts can add an Assist pipeline as well as an entity.
    @Test func magicItemAddForCarPlay() {
        withFakeServers {
            renderInWindow(NavigationView { MagicItemAddView(context: .carPlay) { _ in } })
        }
    }

    @Test func clientEventsLog() {
        renderInWindow(NavigationView { ClientEventsLogView() })
    }

    @Test func databaseTableDetail() {
        renderInWindow(NavigationView { DatabaseTableDetailView(tableName: "hAAppEntity") })
    }

    @Test func notificationHistory() {
        renderInWindow(NavigationView { NotificationHistoryView() })
    }

    @Test func customWidgetsList() {
        withFakeServers {
            renderInWindow(NavigationView { CustomWidgetsListView() })
        }
    }

    @Test func kioskEntryCustomization() {
        withFakeServers {
            renderInWindow(NavigationView { KioskSettingsEntryCustomizationView(viewModel: KioskSettingsViewModel()) })
        }
    }

    #if os(iOS) && !targetEnvironment(macCatalyst)
    @Test func healthSensorRow() {
        renderInWindow(List {
            HealthSensorRow(metric: .steps, stateDescription: "1,234 steps", isEnabled: .constant(true))
            HealthSensorRow(metric: .steps, stateDescription: nil, isEnabled: .constant(false))
        })
    }
    #endif
}
