import AVFoundation
import Foundation
import Shared
import SwiftUI

/// Every text-to-speech voice installed on this device, grouped by language, which is exactly what
/// it advertises to Home Assistant as text-to-speech voices.
struct VoiceToolsServerVoicesView: View {
    /// `nil` while the voice catalog is still loading.
    @State private var voices: [OnDeviceVoice]?
    @State private var searchTerm = ""

    private struct VoiceGroup: Identifiable {
        let language: String
        let displayName: String
        let voices: [OnDeviceVoice]
        var id: String { language }
    }

    init() {}

    /// Injectable so previews and snapshot tests render a fixed list instead of waiting on the
    /// TextToSpeech daemon of the machine rendering them.
    init(voices: [OnDeviceVoice], searchTerm: String = "") {
        self._voices = State(initialValue: voices)
        self._searchTerm = State(initialValue: searchTerm)
    }

    private var voiceGroups: [VoiceGroup] {
        let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        return Dictionary(grouping: voices ?? []) { $0.language }
            .compactMap { language, voices -> VoiceGroup? in
                let displayName = (Locale.current.localizedString(forIdentifier: language) ?? language)
                    .capitalizedFirst
                let matching: [OnDeviceVoice]
                if trimmedSearchTerm.isEmpty || displayName.localizedCaseInsensitiveContains(trimmedSearchTerm) {
                    matching = voices
                } else {
                    matching = voices.filter { $0.name.localizedCaseInsensitiveContains(trimmedSearchTerm) }
                }
                guard !matching.isEmpty else { return nil }
                return VoiceGroup(
                    language: language,
                    displayName: displayName,
                    voices: matching.sorted { $0.name < $1.name }
                )
            }
            .sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        List {
            if let voices, voices.isEmpty {
                Section {
                    Text(L10n.Settings.VoiceToolsServer.Voices.empty)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(Array(voiceGroups.enumerated()), id: \.element.id) { index, group in
                    Section {
                        ForEach(group.voices) { voice in
                            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                                Text(voice.name)
                                if let qualityLabel = qualityLabel(for: voice) {
                                    Text(qualityLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text(group.displayName)
                    } footer: {
                        if index == voiceGroups.count - 1 {
                            Text(L10n.Settings.VoiceToolsServer.Voices.footer)
                        }
                    }
                }
            }
        }
        .overlay {
            if voices == nil {
                ProgressView()
            }
        }
        .searchable(text: $searchTerm)
        .navigationTitle(L10n.Settings.VoiceToolsServer.Voices.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard voices == nil else { return }
            voices = await OnDeviceVoiceCatalog.voices()
        }
    }

    private func qualityLabel(for voice: OnDeviceVoice) -> String? {
        switch voice.quality {
        case .enhanced: return L10n.Assist.Settings.OnDeviceTts.Quality.enhanced
        case .premium: return L10n.Assist.Settings.OnDeviceTts.Quality.premium
        default: return nil
        }
    }
}

#Preview("Voices") {
    NavigationView {
        VoiceToolsServerVoicesView(voices: [
            OnDeviceVoice(
                identifier: "com.apple.voice.compact.en-US.Samantha",
                name: "Samantha",
                language: "en-US",
                quality: .default
            ),
            OnDeviceVoice(
                identifier: "com.apple.voice.enhanced.en-US.Evan",
                name: "Evan",
                language: "en-US",
                quality: .enhanced
            ),
            OnDeviceVoice(
                identifier: "com.apple.voice.premium.pt-BR.Luciana",
                name: "Luciana",
                language: "pt-BR",
                quality: .premium
            ),
        ])
    }
}

#Preview("None") {
    NavigationView {
        VoiceToolsServerVoicesView(voices: [])
    }
}
