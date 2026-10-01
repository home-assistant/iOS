#if os(macOS)
import Shared
import SwiftUI

/// A banner along the bottom of the web view, optionally over a dimmed page: the Mac drawing of the
/// request `DefaultBannerPresenter` is asked to show.
struct MacBannerView: View {
    static let animationDuration: TimeInterval = 0.25

    let request: BannerRequest
    @ObservedObject var model: MacBannerModel
    let onDismiss: () -> Void
    let onAction: () -> Void

    /// How far below its resting place the banner starts and ends its slide.
    private static let hiddenOffset: CGFloat = 120
    private static let shadowRadius: CGFloat = 18
    private static let shadowOffset: CGFloat = 6
    private static let shadowOpacity: CGFloat = 0.18

    var body: some View {
        ZStack(alignment: .bottom) {
            if request.dimming != .none {
                Color(uiColor: request.dimming.color)
                    .opacity(model.isPresented ? 1 : 0)
                    .onTapGesture {
                        if request.dimming.isInteractive {
                            onDismiss()
                        }
                    }
                    .accessibilityLabel(request.dimmingAccessibilityLabel ?? "")
                    .accessibilityAddTraits(request.dimming.isInteractive ? .isButton : [])
            }

            HStack(spacing: DesignSystem.Spaces.oneAndHalf) {
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                    if let title = request.title {
                        Text(title)
                            .font(.headline)
                    }
                    if let message = request.message {
                        Text(message)
                            .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(Color(uiColor: request.style.foregroundColor))

                if let action = request.action {
                    Button(action: onAction) {
                        HStack(spacing: DesignSystem.Spaces.half) {
                            if let image = action.image {
                                Image(uiImage: image)
                                    .renderingMode(.template)
                            }
                            if let title = action.title {
                                Text(title)
                                    .font(.headline)
                            }
                        }
                        .foregroundStyle(Color(uiColor: action.tintColor))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(action.accessibilityLabel ?? action.title ?? "")
                }
            }
            .padding(.vertical, DesignSystem.Spaces.oneAndHalf)
            .padding(.horizontal, DesignSystem.Spaces.two)
            .background(
                Color(uiColor: request.style.backgroundColor),
                in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.two, style: .continuous)
            )
            .shadow(color: .black.opacity(Self.shadowOpacity), radius: Self.shadowRadius, y: Self.shadowOffset)
            .accessibilityIdentifier(request.id)
            .padding(DesignSystem.Spaces.two)
            .background(GeometryReader { proxy in
                Color.clear
                    .onAppear { model.bannerFrame = proxy.frame(in: .global) }
                    .onChange(of: proxy.frame(in: .global)) { model.bannerFrame = $0 }
            })
            .offset(y: model.isPresented ? 0 : Self.hiddenOffset)
            .opacity(model.isPresented ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: Self.animationDuration), value: model.isPresented)
    }
}

#Preview {
    let model = MacBannerModel()
    model.isPresented = true
    return MacBannerView(
        request: .init(
            title: nil,
            message: "An update is available for your server.",
            duration: .forever,
            dimming: .gray(interactive: true),
            style: .warning,
            action: .init(title: "Open", tintColor: .white, handler: {})
        ),
        model: model,
        onDismiss: {},
        onAction: {}
    )
    .frame(width: 480, height: 320)
}
#endif
