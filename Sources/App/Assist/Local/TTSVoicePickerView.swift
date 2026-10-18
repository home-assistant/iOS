import AVFoundation
import Foundation
import Shared
import SwiftUI

struct TTSVoicePickerView: View {
    @Binding var selectedVoiceIdentifier: String?
    @Environment(\.dismiss) private var dismiss
    @State private var searchTerm = ""
    /// `nil` while the voice catalog is still loading.
    @State private var voiceGroups: [VoiceGroup]?

    private struct VoiceGroup: Identifiable {
        let language: String
        let displayName: String
        let voices: [OnDeviceVoice]
        var id: String { language }
    }

    init(selectedVoiceIdentifier: Binding<String?>) {
        self._selectedVoiceIdentifier = selectedVoiceIdentifier
    }

    private var filteredVoiceGroups: [VoiceGroup] {
        let groups = voiceGroups ?? []
        let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchTerm.isEmpty else {
            return groups
        }

        return groups.compactMap { group in
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
                    ForEach(group.voices) { voice in
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
        .overlay {
            if voiceGroups == nil {
                ProgressView()
            }
        }
        .searchable(text: $searchTerm)
        .navigationTitle(L10n.Assist.Settings.OnDeviceTts.voice)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard voiceGroups == nil else { return }
            voiceGroups = await Self.makeVoiceGroups()
        }
    }

    private func qualityLabel(for voice: OnDeviceVoice) -> String? {
        switch voice.quality {
        case .enhanced: return L10n.Assist.Settings.OnDeviceTts.Quality.enhanced
        case .premium: return L10n.Assist.Settings.OnDeviceTts.Quality.premium
        default: return nil
        }
    }

    /// Reading the voice catalog blocks on the TextToSpeech daemon, so the groups are built
    /// asynchronously rather than while the view is created.
    private static func makeVoiceGroups() async -> [VoiceGroup] {
        let voices = await OnDeviceVoiceCatalog.voices()
        let grouped = Dictionary(grouping: voices) { $0.language }
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
}

#Preview {
    NavigationView {
        TTSVoicePickerView(selectedVoiceIdentifier: .constant(nil))
    }
}
