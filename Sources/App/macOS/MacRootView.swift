// Native macOS root view (target: App-macOS).
//
// Lets you point the native app at a Home Assistant instance and renders its
// frontend in a native WKWebView. Login happens through the HA web UI and
// persists in the web view's default data store. Once `Shared` is available on
// macOS, the manual URL field is replaced by real server management/onboarding.

#if os(macOS)
import SwiftUI

struct MacRootView: View {
    @AppStorage("mac.lastServerURL") private var savedURLString: String = ""
    @State private var draftURLString: String = ""
    @State private var loadedURL: URL?

    var body: some View {
        Group {
            if let loadedURL {
                MacWebViewHost(url: loadedURL)
                    .id(loadedURL)
            } else {
                connectForm
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .toolbar {
            if loadedURL != nil {
                ToolbarItem(placement: .navigation) {
                    Button {
                        loadedURL = nil
                    } label: {
                        Label("Change server", systemImage: "arrow.left")
                    }
                }
                ToolbarItem {
                    Button {
                        NotificationCenter.default.post(name: .macWebReload, object: nil)
                    } label: {
                        Label("Reload", systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r", modifiers: .command)
                }
            }
        }
        .onAppear {
            // Optional override (kiosk-less MDM / testing): HA_MAC_DEFAULT_URL.
            let envURL = ProcessInfo.processInfo.environment["HA_MAC_DEFAULT_URL"] ?? ""
            let initial = envURL.isEmpty ? savedURLString : envURL
            draftURLString = initial
            loadedURL = Self.normalized(initial)
            MacTrace.write("onAppear initial='\(initial)' normalized=\(loadedURL?.absoluteString ?? "nil")")
        }
    }

    private var connectForm: some View {
        VStack(spacing: 16) {
            Image(systemName: "house")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(verbatim: "Home Assistant")
                .font(.title.bold())
            Text(verbatim: "Enter your Home Assistant URL")
                .foregroundStyle(.secondary)
            HStack {
                TextField("https://homeassistant.local:8123", text: $draftURLString)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
                    .onSubmit(connect)
                Button("Connect", action: connect)
                    .keyboardShortcut(.defaultAction)
                    .disabled(Self.normalized(draftURLString) == nil)
            }
        }
        .padding(40)
    }

    private func connect() {
        guard let url = Self.normalized(draftURLString) else { return }
        savedURLString = url.absoluteString
        loadedURL = url
    }

    /// Accepts bare hosts ("homeassistant.local:8123") and full URLs, defaulting to https.
    static func normalized(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: withScheme), url.host != nil else { return nil }
        return url
    }
}
#endif
