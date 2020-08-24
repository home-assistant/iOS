import Foundation
import UIKit

class MenuManager {
    let builder: UIMenuBuilder

    init(builder: UIMenuBuilder) {
        self.builder = builder
        update()
    }

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Home Assistant"
    }

    private func update() {
        builder.remove(menu: .format)

        builder.replace(menu: .about, with: aboutMenu())
        builder.insertSibling(preferencesMenu(), afterMenu: .about)
        builder.replaceChildren(ofMenu: .help) { _ in helpMenus() }
    }

    private func aboutMenu() -> UIMenu {
        let title = L10n.Menu.Application.about(appName)

        let command = UICommand(
            title: title,
            image: nil,
            action: #selector(AppDelegate.openAbout),
            propertyList: nil
        )

        return UIMenu(
            title: title,
            image: nil,
            identifier: .about,
            options: .displayInline,
            children: [command]
        )
    }

    private func preferencesMenu() -> UIMenu {
        let command = UIKeyCommand(
            title: L10n.Menu.Application.preferences,
            image: nil,
            action: #selector(AppDelegate.openPreferences),
            input: ",",
            modifierFlags: .command,
            propertyList: nil
        )

        return UIMenu(
            title: L10n.Menu.Application.preferences,
            image: nil,
            identifier: .preferences,
            options: .displayInline,
            children: [command]
        )
    }

    private func helpMenus() -> [UIMenu] {
        let title = L10n.Menu.Help.help(appName)

        let helpCommand = UICommand(
            title: title,
            image: nil,
            action: #selector(AppDelegate.openHelp),
            propertyList: nil
        )

        return [
            UIMenu(
                title: title,
                image: nil,
                identifier: .init(rawValue: "ha.help"),
                options: .displayInline,
                children: [helpCommand]
            )
        ]
    }
}
