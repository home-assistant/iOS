import CarPlay
import Foundation
import Shared

/// CarPlay screen exposing the same Assist settings as the in-app `AssistSettingsView`.
/// Both read and write the `AssistConfiguration` database singleton, so the selection is
/// global across phone and car.
final class CarPlayAssistSettingsTemplate {
    private weak var interfaceController: CPInterfaceController?
    private weak var template: CPListTemplate?

    /// Name of the selected text-to-speech voice. Resolving an identifier waits on the
    /// TextToSpeech daemon, which is far too slow to do while building the list, so the row shows
    /// this cached value and `loadSelectedVoiceDisplayName()` refreshes it in the background.
    private var selectedVoiceDisplayName = L10n.Assist.Settings.OnDeviceTts.defaultVoice

    private var configuration: AssistConfiguration {
        AssistConfiguration.config
    }

    func present(using interfaceController: CPInterfaceController?) {
        self.interfaceController = interfaceController
        let template = CPListTemplate(title: L10n.Assist.Settings.title, sections: [])
        self.template = template
        template.updateSections(makeSections())
        loadSelectedVoiceDisplayName()
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    private func reload() {
        template?.updateSections(makeSections())
    }

    // The in-app mute toggle is intentionally absent: muteTTS does not apply to CarPlay,
    // where voice responses always play.
    private func makeSections() -> [CPListSection] {
        guard #available(iOS 17.0, *) else { return [] }
        var items = [onDeviceSTTItem]
        if configuration.enableOnDeviceSTT {
            items.append(sttLanguageItem)
        }
        items.append(onDeviceTTSItem)
        if configuration.enableOnDeviceTTS {
            items.append(ttsVoiceItem)
        }
        return [CPListSection(items: items)]
    }

    private func updateConfiguration(_ mutate: (inout AssistConfiguration) -> Void) {
        var configuration = AssistConfiguration.config
        mutate(&configuration)
        configuration.save()
        reload()
    }

    @available(iOS 17.0, *)
    private var onDeviceSTTItem: CPListItem {
        let item = CPListItem(
            text: L10n.Assist.Settings.OnDeviceStt.title,
            detailText: nil,
            image: configuration.enableOnDeviceSTT ? MaterialDesignIcons.checkIcon.carPlayIcon() : nil
        )
        item.accessoryType = .none
        item.handler = { [weak self] _, completion in
            self?.updateConfiguration { $0.enableOnDeviceSTT.toggle() }
            self?.selectDefaultSTTLocaleIfNeeded()
            completion()
        }
        return item
    }

    /// Same behavior as the in-app settings: default to a supported locale when the current one is
    /// unset or not supported for on-device recognition. Determining the supported locales blocks
    /// its caller for close to a second, so it happens off the main thread and the list refreshes
    /// once the answer arrives.
    @available(iOS 17.0, *)
    private func selectDefaultSTTLocaleIfNeeded() {
        guard configuration.enableOnDeviceSTT else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let supportedIdentifiers = await SupportedSpeechLocales.shared.locales().map(\.identifier)
            // Re-read the configuration: the toggle can flip again while the probe runs.
            guard configuration.enableOnDeviceSTT,
                  !supportedIdentifiers.contains(configuration.onDeviceSTTLocaleIdentifier ?? "") else { return }
            updateConfiguration { $0.onDeviceSTTLocaleIdentifier = supportedIdentifiers.first }
        }
    }

    @available(iOS 17.0, *)
    private var sttLanguageItem: CPListItem {
        let item = CPListItem(
            text: L10n.Assist.Settings.OnDeviceStt.language,
            detailText: localeDisplayName(configuration.onDeviceSTTLocaleIdentifier)
        )
        item.accessoryType = .disclosureIndicator
        item.handler = { [weak self] _, completion in
            self?.presentSTTLanguageSelection()
            completion()
        }
        return item
    }

    @available(iOS 17.0, *)
    private func presentSTTLanguageSelection() {
        let selectionTemplate = CPListTemplate(title: L10n.Assist.Settings.OnDeviceStt.language, sections: [])
        interfaceController?.pushTemplate(selectionTemplate, animated: true, completion: nil)

        // Pushed empty on purpose: the supported locales come from a probe that would otherwise
        // hang the main thread while the template is built.
        Task { @MainActor [weak self] in
            guard let self else { return }
            let selectedIdentifier = configuration.onDeviceSTTLocaleIdentifier
            let locales = await SupportedSpeechLocales.shared.locales()
            let items = locales.map { locale in
                let item = CPListItem(
                    text: localeDisplayName(locale.identifier) ?? locale.identifier,
                    detailText: nil,
                    image: locale.identifier == selectedIdentifier ? MaterialDesignIcons.checkIcon.carPlayIcon() : nil
                )
                item.accessoryType = .none
                item.handler = { [weak self] _, completion in
                    self?.updateConfiguration { $0.onDeviceSTTLocaleIdentifier = locale.identifier }
                    self?.interfaceController?.popTemplate(animated: true, completion: nil)
                    completion()
                }
                return item
            }
            selectionTemplate.updateSections([CPListSection(items: items)])
        }
    }

    private var onDeviceTTSItem: CPListItem {
        let item = CPListItem(
            text: L10n.Assist.Settings.OnDeviceTts.title,
            detailText: nil,
            image: configuration.enableOnDeviceTTS ? MaterialDesignIcons.checkIcon.carPlayIcon() : nil
        )
        item.accessoryType = .none
        item.handler = { [weak self] _, completion in
            self?.updateConfiguration { $0.enableOnDeviceTTS.toggle() }
            completion()
        }
        return item
    }

    private var ttsVoiceItem: CPListItem {
        let item = CPListItem(
            text: L10n.Assist.Settings.OnDeviceTts.voice,
            detailText: selectedVoiceDisplayName
        )
        item.accessoryType = .disclosureIndicator
        item.handler = { [weak self] _, completion in
            self?.presentTTSVoiceSelection()
            completion()
        }
        return item
    }

    private func loadSelectedVoiceDisplayName() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let name: String
            if let identifier = configuration.onDeviceTTSVoiceIdentifier {
                let voice = await OnDeviceVoiceCatalog.voice(withIdentifier: identifier)
                name = voice?.name ?? L10n.Assist.Settings.OnDeviceTts.defaultVoice
            } else {
                name = L10n.Assist.Settings.OnDeviceTts.defaultVoice
            }
            guard name != selectedVoiceDisplayName else { return }
            selectedVoiceDisplayName = name
            reload()
        }
    }

    private func presentTTSVoiceSelection() {
        let selectionTemplate = CPListTemplate(title: L10n.Assist.Settings.OnDeviceTts.voice, sections: [])
        interfaceController?.pushTemplate(selectionTemplate, animated: true, completion: nil)

        // Pushed empty on purpose: reading the installed voices waits on the TextToSpeech daemon
        // and would hang the main thread while the template is built.
        Task { @MainActor [weak self] in
            guard let self else { return }
            let selectedIdentifier = configuration.onDeviceTTSVoiceIdentifier

            let defaultItem = CPListItem(
                text: L10n.Assist.Settings.OnDeviceTts.defaultVoice,
                detailText: nil,
                image: selectedIdentifier == nil ? MaterialDesignIcons.checkIcon.carPlayIcon() : nil
            )
            defaultItem.accessoryType = .none
            defaultItem.handler = { [weak self] _, completion in
                self?.selectedVoiceDisplayName = L10n.Assist.Settings.OnDeviceTts.defaultVoice
                self?.updateConfiguration { $0.onDeviceTTSVoiceIdentifier = nil }
                self?.interfaceController?.popTemplate(animated: true, completion: nil)
                completion()
            }

            let voices = await selectableVoices(selectedIdentifier: selectedIdentifier)
            let items = [defaultItem] + voices.map { voice in
                let item = CPListItem(
                    text: voice.name,
                    detailText: localeDisplayName(voice.language),
                    image: voice.identifier == selectedIdentifier ? MaterialDesignIcons.checkIcon.carPlayIcon() : nil
                )
                item.accessoryType = .none
                item.handler = { [weak self] _, completion in
                    self?.selectedVoiceDisplayName = voice.name
                    self?.updateConfiguration { $0.onDeviceTTSVoiceIdentifier = voice.identifier }
                    self?.interfaceController?.popTemplate(animated: true, completion: nil)
                    completion()
                }
                return item
            }
            selectionTemplate.updateSections([CPListSection(items: items)])
        }
    }

    /// The full voice catalog is too long for a driver-facing list, so the car offers the
    /// voices matching the device language (plus the currently selected voice); the complete
    /// searchable catalog stays available in the in-app settings.
    private func selectableVoices(selectedIdentifier: String?) async -> [OnDeviceVoice] {
        let languageCode = Locale.current.language.languageCode?.identifier ?? Locale.current.identifier
        let allVoices = await OnDeviceVoiceCatalog.voices()
        var voices = allVoices.filter { $0.language.hasPrefix(languageCode) }
        if let selectedIdentifier,
           !voices.contains(where: { $0.identifier == selectedIdentifier }),
           let selectedVoice = allVoices.first(where: { $0.identifier == selectedIdentifier }) {
            voices.append(selectedVoice)
        }
        return voices.sorted { $0.name < $1.name }
    }

    private func localeDisplayName(_ identifier: String?) -> String? {
        guard let identifier else { return nil }
        return Locale.current.localizedString(forIdentifier: identifier)?.capitalizedFirst ?? identifier
    }
}
