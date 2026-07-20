import AVFoundation
import CarPlay
import Foundation
import Shared

/// CarPlay screen exposing the same Assist settings as the in-app `AssistSettingsView`.
/// Both read and write the `AssistConfiguration` database singleton, so the selection is
/// global across phone and car.
final class CarPlayAssistSettingsTemplate {
    private weak var interfaceController: CPInterfaceController?
    private weak var template: CPListTemplate?

    private var configuration: AssistConfiguration {
        AssistConfiguration.config
    }

    func present(using interfaceController: CPInterfaceController?) {
        self.interfaceController = interfaceController
        let template = CPListTemplate(title: L10n.Assist.Settings.title, sections: [])
        self.template = template
        template.updateSections(makeSections())
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    private func reload() {
        template?.updateSections(makeSections())
    }

    private func makeSections() -> [CPListSection] {
        var items = [muteTTSItem]
        if #available(iOS 17.0, *) {
            items.append(onDeviceSTTItem)
            if configuration.enableOnDeviceSTT {
                items.append(sttLanguageItem)
            }
            items.append(onDeviceTTSItem)
            if configuration.enableOnDeviceTTS {
                items.append(ttsVoiceItem)
            }
        }
        return [CPListSection(items: items)]
    }

    private func updateConfiguration(_ mutate: (inout AssistConfiguration) -> Void) {
        var configuration = AssistConfiguration.config
        mutate(&configuration)
        configuration.save()
        reload()
    }

    private var muteTTSItem: CPListItem {
        let item = CPListItem(
            text: L10n.Assist.Settings.TtsMute.toggle,
            detailText: nil,
            image: configuration.muteTTS ? MaterialDesignIcons.checkIcon.carPlayIcon() : nil
        )
        item.accessoryType = .none
        item.handler = { [weak self] _, completion in
            self?.updateConfiguration { $0.muteTTS.toggle() }
            completion()
        }
        return item
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
            self?.updateConfiguration { configuration in
                configuration.enableOnDeviceSTT.toggle()
                guard configuration.enableOnDeviceSTT else { return }
                // Same behavior as the in-app settings: default to a supported locale when
                // the current one is unset or not supported for on-device recognition.
                let supportedIdentifiers = SpeechTranscriber.supportedLocales.map(\.identifier)
                if !supportedIdentifiers.contains(configuration.onDeviceSTTLocaleIdentifier ?? "") {
                    configuration.onDeviceSTTLocaleIdentifier = supportedIdentifiers.first
                }
            }
            completion()
        }
        return item
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
        let selectedIdentifier = configuration.onDeviceSTTLocaleIdentifier
        let items = SpeechTranscriber.supportedLocales.map { locale in
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
        interfaceController?.pushTemplate(selectionTemplate, animated: true, completion: nil)
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

    private var selectedVoiceDisplayName: String {
        guard let identifier = configuration.onDeviceTTSVoiceIdentifier,
              let voice = AVSpeechSynthesisVoice(identifier: identifier) else {
            return L10n.Assist.Settings.OnDeviceTts.defaultVoice
        }
        return voice.name
    }

    private func presentTTSVoiceSelection() {
        let selectionTemplate = CPListTemplate(title: L10n.Assist.Settings.OnDeviceTts.voice, sections: [])
        let selectedIdentifier = configuration.onDeviceTTSVoiceIdentifier

        let defaultItem = CPListItem(
            text: L10n.Assist.Settings.OnDeviceTts.defaultVoice,
            detailText: nil,
            image: selectedIdentifier == nil ? MaterialDesignIcons.checkIcon.carPlayIcon() : nil
        )
        defaultItem.accessoryType = .none
        defaultItem.handler = { [weak self] _, completion in
            self?.updateConfiguration { $0.onDeviceTTSVoiceIdentifier = nil }
            self?.interfaceController?.popTemplate(animated: true, completion: nil)
            completion()
        }

        let items = [defaultItem] + selectableVoices(selectedIdentifier: selectedIdentifier).map { voice in
            let item = CPListItem(
                text: voice.name,
                detailText: localeDisplayName(voice.language),
                image: voice.identifier == selectedIdentifier ? MaterialDesignIcons.checkIcon.carPlayIcon() : nil
            )
            item.accessoryType = .none
            item.handler = { [weak self] _, completion in
                self?.updateConfiguration { $0.onDeviceTTSVoiceIdentifier = voice.identifier }
                self?.interfaceController?.popTemplate(animated: true, completion: nil)
                completion()
            }
            return item
        }
        selectionTemplate.updateSections([CPListSection(items: items)])
        interfaceController?.pushTemplate(selectionTemplate, animated: true, completion: nil)
    }

    /// The full voice catalog is too long for a driver-facing list, so the car offers the
    /// voices matching the device language (plus the currently selected voice); the complete
    /// searchable catalog stays available in the in-app settings.
    private func selectableVoices(selectedIdentifier: String?) -> [AVSpeechSynthesisVoice] {
        let languageCode = Locale.current.language.languageCode?.identifier ?? Locale.current.identifier
        var voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(languageCode) }
        if let selectedIdentifier,
           !voices.contains(where: { $0.identifier == selectedIdentifier }),
           let selectedVoice = AVSpeechSynthesisVoice(identifier: selectedIdentifier) {
            voices.append(selectedVoice)
        }
        return voices.sorted { $0.name < $1.name }
    }

    private func localeDisplayName(_ identifier: String?) -> String? {
        guard let identifier else { return nil }
        return Locale.current.localizedString(forIdentifier: identifier)?.capitalizedFirst ?? identifier
    }
}
