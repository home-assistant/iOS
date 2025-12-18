import Shared
import SwiftUI

struct WebViewLoadingStateView: View {
    @State private var showText = false
    @State private var showSettingsButton = false
    let onOpenSettings: () -> Void
    
    var body: some View {
        VStack(spacing: DesignSystem.Spaces.four) {
            HAProgressView(style: .large)
            if showText {
                Text(L10n.LoadingState.waitingText)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
            
            if showSettingsButton {
                Button {
                    onOpenSettings()
                } label: {
                    Label(L10n.Settings.NavigationBar.title, systemSymbol: .gearshapeFill)
                        .font(.headline)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thickMaterial)
        .ignoresSafeArea()
        .task {
            if #available(iOS 16.0, *) {
                try? await Task.sleep(for: .seconds(5))
            } else {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
            withAnimation {
                showText = true
            }
            
            // Wait additional 3 seconds (8 seconds total)
            if #available(iOS 16.0, *) {
                try? await Task.sleep(for: .seconds(3))
            } else {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
            withAnimation {
                showSettingsButton = true
            }
        }
    }
}

@available(iOS 18.0, *)
private struct MeshGradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var time: Float = 0.0
    
    var body: some View {
        VStack {}
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        // Row 0
                        [0.0, 0.0],
                        [0.5 + 0.1 * sin(time), 0.0 + 0.1 * cos(time * 0.8)],
                        [1.0, 0.0],
                        // Row 1
                        [0.0 + 0.1 * cos(time * 1.2), 0.5 + 0.1 * sin(time * 0.9)],
                        [0.5 + 0.15 * sin(time * 1.1), 0.5 + 0.15 * cos(time * 1.3)],
                        [1.0 + 0.1 * sin(time * 0.7), 0.5 + 0.1 * cos(time)],
                        // Row 2
                        [0.0, 1.0],
                        [0.5 + 0.1 * cos(time * 1.4), 1.0 + 0.1 * sin(time * 0.6)],
                        [1.0, 1.0]
                    ],
                    colors: colorScheme == .dark ? [
                        // Row 0 - Dark mode
                        .black, .indigo, .blue,
                        // Row 1
                        .blue, .black, .cyan,
                        // Row 2
                        .indigo, .teal, .black
                    ] : [
                        // Row 0 - Light mode
                        .white, .cyan, .blue,
                        // Row 1
                        .blue, .white, .cyan,
                        // Row 2
                        .indigo, .teal, .white
                    ]
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                    time = .pi * 2
                }
            }
    }
}

#Preview {
    ZStack {
        Group {
            if #available(iOS 18.0, *) {
                MeshGradientBackground()
            } else {
                VStack {}
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        LinearGradient(
                            colors: [.blue, .cyan, .teal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .ignoresSafeArea()
        WebViewLoadingStateView(onOpenSettings: {
            print("Settings button tapped")
        })
    }
}

