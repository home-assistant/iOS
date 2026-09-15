import Foundation

/// The copy the generated dashboard needs. Handed in rather than looked up: the design system ships
/// no string tables, and it is the app's translations that have to end up on screen — the same
/// arrangement the widgets here use.
///
/// The defaults are the frontend's own English, so the strategies can be read, previewed and
/// snapshot-tested standalone.
public struct HomeDashboardStrings: Equatable, Sendable {
    public var lights: String
    public var climate: String
    public var security: String
    public var maintenance: String
    public var mediaPlayers: String
    public var energy: String
    public var presence: String
    public var weather: String
    public var areas: String
    public var otherAreas: String
    public var devices: String
    public var summaries: String
    public var favorites: String
    public var scenes: String
    public var automations: String
    public var others: String
    public var unnamedDevice: String
    /// Greets the user. `{user}` is replaced with their name.
    public var welcomeUser: String
    public var noDevicesTitle: String
    public var noDevicesContent: String
    public var addDevice: String
    public var editAreas: String
    public var areaNoDevicesTitle: String
    public var areaNoDevicesContent: String
    public var assignDevice: String
    /// The heading over media players that belong to no room, when other rooms came first.
    public var otherMediaPlayers: String
    /// The other-devices view when there is nothing left to file away.
    public var allOrganizedTitle: String
    public var allOrganizedContent: String
    /// Shown while the server is still starting up.
    public var startingTitle: String
    public var startingContent: String
    /// Shown when the server came up in recovery mode.
    public var recoveryModeTitle: String
    public var recoveryModeContent: String
    /// The lines under each summary. `{count}` is replaced with how many, and the counted ones come
    /// in a pair so a language that inflects can say "1 low battery" and "2 low batteries".
    public var allLightsOff: String
    public var lightsOnFormat: String
    public var locksUnlockedFormat: String
    public var alarmsDisarmedFormat: String
    public var allSecure: String
    public var noMediaPlaying: String
    public var mediaPlayingFormat: String
    public var lowBatteryFormat: String
    public var lowBatteriesFormat: String
    public var unavailableDeviceFormat: String
    public var unavailableDevicesFormat: String
    public var allMaintenanceGood: String
    public var personHomeFormat: String
    public var peopleHomeFormat: String
    public var nobodyHome: String
    /// Accessibility labels for the controls under a tile.
    public var brightness: String
    public var coverOpen: String
    public var coverStop: String
    public var coverClose: String
    public var lock: String
    public var unlock: String
    /// The badge over a room's lights while any of them is on. Tapping it turns them off.
    public var lightsOn: String
    /// And while they are all off.
    public var lightsOff: String

    public init(
        lights: String = "Lights",
        climate: String = "Climate",
        security: String = "Security",
        maintenance: String = "Maintenance",
        mediaPlayers: String = "Media players",
        energy: String = "Today's energy",
        presence: String = "Presence",
        weather: String = "Weather",
        areas: String = "Areas",
        otherAreas: String = "Other areas",
        devices: String = "Devices",
        summaries: String = "Summaries",
        favorites: String = "Favorites",
        scenes: String = "Scenes",
        automations: String = "Automations",
        others: String = "Others",
        unnamedDevice: String = "Unnamed device",
        welcomeUser: String = "Welcome {user}",
        noDevicesTitle: String = "No devices here yet",
        noDevicesContent: String = "Add lights, switches, sensors, or other smart home devices to get started.",
        addDevice: String = "Add new device",
        editAreas: String = "Edit areas",
        areaNoDevicesTitle: String = "This is a blank canvas",
        areaNoDevicesContent: String = "Add your smart lights, switches, or sensors to this area to get started.",
        assignDevice: String = "Assign existing device",
        otherMediaPlayers: String = "Other media players",
        allOrganizedTitle: String = "All devices are organized",
        allOrganizedContent: String = "There are no unassigned devices left. All devices are organized into areas.",
        startingTitle: String = "Home Assistant is starting",
        startingContent: String = "Your home will appear here once it has finished starting up.",
        recoveryModeTitle: String = "Recovery mode",
        recoveryModeContent: String = "Home Assistant is running in recovery mode, so there is nothing to show here.",
        allLightsOff: String = "All off",
        lightsOnFormat: String = "{count} on",
        locksUnlockedFormat: String = "{count} unlocked",
        alarmsDisarmedFormat: String = "{count} disarmed",
        allSecure: String = "All secure",
        noMediaPlaying: String = "No media playing",
        mediaPlayingFormat: String = "{count} playing",
        lowBatteryFormat: String = "{count} low battery",
        lowBatteriesFormat: String = "{count} low batteries",
        unavailableDeviceFormat: String = "{count} unavailable device",
        unavailableDevicesFormat: String = "{count} unavailable devices",
        allMaintenanceGood: String = "All good",
        personHomeFormat: String = "{count} person home",
        peopleHomeFormat: String = "{count} people home",
        nobodyHome: String = "No one home",
        brightness: String = "Brightness",
        coverOpen: String = "Open",
        coverStop: String = "Stop",
        coverClose: String = "Close",
        lock: String = "Lock",
        unlock: String = "Unlock",
        lightsOn: String = "On",
        lightsOff: String = "Off"
    ) {
        self.lights = lights
        self.climate = climate
        self.security = security
        self.maintenance = maintenance
        self.mediaPlayers = mediaPlayers
        self.energy = energy
        self.presence = presence
        self.weather = weather
        self.areas = areas
        self.otherAreas = otherAreas
        self.devices = devices
        self.summaries = summaries
        self.favorites = favorites
        self.scenes = scenes
        self.automations = automations
        self.others = others
        self.unnamedDevice = unnamedDevice
        self.welcomeUser = welcomeUser
        self.noDevicesTitle = noDevicesTitle
        self.noDevicesContent = noDevicesContent
        self.addDevice = addDevice
        self.editAreas = editAreas
        self.areaNoDevicesTitle = areaNoDevicesTitle
        self.areaNoDevicesContent = areaNoDevicesContent
        self.assignDevice = assignDevice
        self.otherMediaPlayers = otherMediaPlayers
        self.allOrganizedTitle = allOrganizedTitle
        self.allOrganizedContent = allOrganizedContent
        self.startingTitle = startingTitle
        self.startingContent = startingContent
        self.recoveryModeTitle = recoveryModeTitle
        self.recoveryModeContent = recoveryModeContent
        self.allLightsOff = allLightsOff
        self.lightsOnFormat = lightsOnFormat
        self.locksUnlockedFormat = locksUnlockedFormat
        self.alarmsDisarmedFormat = alarmsDisarmedFormat
        self.allSecure = allSecure
        self.noMediaPlaying = noMediaPlaying
        self.mediaPlayingFormat = mediaPlayingFormat
        self.lowBatteryFormat = lowBatteryFormat
        self.lowBatteriesFormat = lowBatteriesFormat
        self.unavailableDeviceFormat = unavailableDeviceFormat
        self.unavailableDevicesFormat = unavailableDevicesFormat
        self.allMaintenanceGood = allMaintenanceGood
        self.personHomeFormat = personHomeFormat
        self.peopleHomeFormat = peopleHomeFormat
        self.nobodyHome = nobodyHome
        self.brightness = brightness
        self.coverOpen = coverOpen
        self.coverStop = coverStop
        self.coverClose = coverClose
        self.lock = lock
        self.unlock = unlock
        self.lightsOn = lightsOn
        self.lightsOff = lightsOff
    }

    /// The frontend's English, for previews, tests and the component gallery.
    public static let preview = HomeDashboardStrings()

    public func countLightsOn(_ count: Int) -> String { counted(lightsOnFormat, count) }
    public func countLocksUnlocked(_ count: Int) -> String { counted(locksUnlockedFormat, count) }
    public func countAlarmsDisarmed(_ count: Int) -> String { counted(alarmsDisarmedFormat, count) }
    public func countMediaPlaying(_ count: Int) -> String { counted(mediaPlayingFormat, count) }

    public func countLowBatteries(_ count: Int) -> String {
        counted(count == 1 ? lowBatteryFormat : lowBatteriesFormat, count)
    }

    public func countUnavailableDevices(_ count: Int) -> String {
        counted(count == 1 ? unavailableDeviceFormat : unavailableDevicesFormat, count)
    }

    public func countPeopleHome(_ count: Int) -> String {
        counted(count == 1 ? personHomeFormat : peopleHomeFormat, count)
    }

    private func counted(_ format: String, _ count: Int) -> String {
        format.replacingOccurrences(of: "{count}", with: String(count))
    }

    /// The title a summary goes by.
    public func title(for summary: HomeSummaryKind) -> String {
        switch summary {
        case .light: lights
        case .climate: climate
        case .security: security
        case .maintenance: maintenance
        case .mediaPlayers: mediaPlayers
        case .energy: energy
        case .persons: presence
        case .weather: weather
        }
    }
}
