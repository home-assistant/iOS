import Shared
import SwiftUI

/// How to get from this screen to music playing: adding the speaker to Music Assistant, and then
/// using it from Home Assistant.
struct SendspinConnectInstructionsView: View {
    /// YAML is the same in every language, so it is not localized.
    static let exampleAction = """
    action: music_assistant.play_media
    target:
      entity_id: media_player.iphone
    data:
      media_id: Clair de Lune
      media_type: track
    """

    var body: some View {
        List {
            Section {
                ForEach(Array([
                    L10n.Settings.Sendspin.Connect.step1,
                    L10n.Settings.Sendspin.Connect.step2,
                    L10n.Settings.Sendspin.Connect.step3,
                    L10n.Settings.Sendspin.Connect.step4,
                ].enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(verbatim: "\(index + 1)")
                            .font(.body.monospacedDigit().weight(.semibold))
                            .foregroundStyle(Color.haPrimary)
                        Text(step)
                    }
                }
            } header: {
                Text(L10n.Settings.Sendspin.Connect.MusicAssistant.header)
            } footer: {
                Text(L10n.Settings.Sendspin.Connect.MusicAssistant.footer)
            }

            Section {
                Text(L10n.Settings.Sendspin.Connect.HomeAssistant.body)
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.Settings.Sendspin.Connect.HomeAssistant.example)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(verbatim: Self.exampleAction)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
            } header: {
                Text(L10n.Settings.Sendspin.Connect.HomeAssistant.header)
            }
        }
        .navigationTitle(L10n.Settings.Sendspin.Connect.title)
    }
}

#Preview {
    NavigationView {
        SendspinConnectInstructionsView()
    }
}
