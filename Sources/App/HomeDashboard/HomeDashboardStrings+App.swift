import Shared

extension HomeDashboardStrings {
    /// The generated dashboard's copy in the user's language. The design system ships English
    /// defaults so it can be previewed on its own; these are what actually reach the screen.
    static var app: HomeDashboardStrings {
        HomeDashboardStrings(
            lights: L10n.HomeDashboard.Summary.lights,
            climate: L10n.HomeDashboard.Summary.climate,
            security: L10n.HomeDashboard.Summary.security,
            maintenance: L10n.HomeDashboard.Summary.maintenance,
            mediaPlayers: L10n.HomeDashboard.Summary.mediaPlayers,
            energy: L10n.HomeDashboard.Summary.energy,
            presence: L10n.HomeDashboard.Summary.presence,
            weather: L10n.HomeDashboard.Summary.weather,
            areas: L10n.HomeDashboard.Section.areas,
            otherAreas: L10n.HomeDashboard.Section.otherAreas,
            devices: L10n.HomeDashboard.Section.devices,
            summaries: L10n.HomeDashboard.Section.summaries,
            favorites: L10n.HomeDashboard.Section.favorites,
            scenes: L10n.HomeDashboard.Section.scenes,
            automations: L10n.HomeDashboard.Section.automations,
            others: L10n.HomeDashboard.Section.others,
            unnamedDevice: L10n.HomeDashboard.unnamedDevice,
            welcomeUser: L10n.HomeDashboard.welcomeUser("{user}"),
            noDevicesTitle: L10n.HomeDashboard.EmptyHome.title,
            noDevicesContent: L10n.HomeDashboard.EmptyHome.body,
            addDevice: L10n.HomeDashboard.EmptyHome.addDevice,
            editAreas: L10n.HomeDashboard.EmptyHome.editAreas,
            areaNoDevicesTitle: L10n.HomeDashboard.EmptyArea.title,
            areaNoDevicesContent: L10n.HomeDashboard.EmptyArea.body,
            assignDevice: L10n.HomeDashboard.EmptyArea.assignDevice,
            startingTitle: L10n.HomeDashboard.Starting.title,
            startingContent: L10n.HomeDashboard.Starting.body,
            recoveryModeTitle: L10n.HomeDashboard.RecoveryMode.title,
            recoveryModeContent: L10n.HomeDashboard.RecoveryMode.body,
            summaryNoneActive: L10n.HomeDashboard.Summary.noneActive,
            summaryActiveCountFormat: L10n.HomeDashboard.Summary.activeCount("{count}"),
            brightness: L10n.HomeDashboard.Control.brightness,
            coverOpen: L10n.HomeDashboard.Control.open,
            coverStop: L10n.HomeDashboard.Control.stop,
            coverClose: L10n.HomeDashboard.Control.close,
            lock: L10n.HomeDashboard.Control.lock,
            unlock: L10n.HomeDashboard.Control.unlock,
            lightsOn: L10n.HomeDashboard.Lights.on,
            lightsOff: L10n.HomeDashboard.Lights.off
        )
    }
}
