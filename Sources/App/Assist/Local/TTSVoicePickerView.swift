import AVFoundation
import Foundation
import Shared
import SwiftUI

struct TTSVoicePickerView: View {
    @Binding var selectedVoiceIdentifier: String?
    @Environment(\.dismiss) private var dismiss
    @State private var searchTerm = ""

    private struct VoiceGroup: Identifiable {
        let language: String
        let displayName: String
        let voices: [AVSpeechSynthesisVoice]
        var id: String { language }
    }

    private var voiceGroups: [VoiceGroup] {
        let grouped = Dictionary(grouping: AVSpeechSynthesisVoice.speechVoices()) { $0.language }
        return grouped
            .map { language, voices in
                VoiceGroup(
                    language: language,
                    displayName: Locale.current.localizedString(forIdentifier: language) ?? language,
                    voices: voices.sorted { $0.name < $1.name }
                )
            }
            .sorted { $0.displayName < $1.displayName }
    }

    private var filteredVoiceGroups: [VoiceGroup] {
        let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchTerm.isEmpty else {
            return voiceGroups
        }

        return voiceGroups.compactMap { group in
            if group.displayName.localizedCaseInsensitiveContains(trimmedSearchTerm) {
                return group
            }

            let matchingVoices = group.voices.filter { voice in
                voice.name.localizedCaseInsensitiveContains(trimmedSearchTerm)
                    || qualityLabel(for: voice)?.localizedCaseInsensitiveContains(trimmedSearchTerm) == true
            }

            guard !matchingVoices.isEmpty else {
                return nil
            }

            return VoiceGroup(
                language: group.language,
                displayName: group.displayName,
                voices: matchingVoices
            )
        }
    }

    var body: some View {
        List {
            Section {
                Button {
                    selectedVoiceIdentifier = nil
                    dismiss()
                } label: {
                    HStack {
                        Text(L10n.Assist.Settings.OnDeviceTts.defaultVoice)
                            .foregroundStyle(Color.primary)
                        Spacer()
                        if selectedVoiceIdentifier == nil {
                            Image(systemSymbol: .checkmark)
                                .foregroundStyle(Color.haPrimary)
                        }
                    }
                }
            }

            ForEach(filteredVoiceGroups) { group in
                Section(group.displayName.capitalizedFirst) {
                    ForEach(group.voices, id: \.identifier) { voice in
                        Button {
                            selectedVoiceIdentifier = voice.identifier
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(voice.name)
                                        .foregroundStyle(Color.primary)
                                    if let qualityLabel = qualityLabel(for: voice) {
                                        Text(qualityLabel)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if voice.identifier == selectedVoiceIdentifier {
                                    Image(systemSymbol: .checkmark)
                                        .foregroundStyle(Color.haPrimary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchTerm)
        .navigationTitle(L10n.Assist.Settings.OnDeviceTts.voice)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func qualityLabel(for voice: AVSpeechSynthesisVoice) -> String? {
        switch voice.quality {
        case .enhanced: return L10n.Assist.Settings.OnDeviceTts.Quality.enhanced
        case .premium: return L10n.Assist.Settings.OnDeviceTts.Quality.premium
        default: return nil
        }
    }
}
