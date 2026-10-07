import Shared

enum MacSettingsSidebarSelection: Hashable {
    case item(SettingsItem)
    case server(Identifier<Server>)
    case serverSwitching
}
