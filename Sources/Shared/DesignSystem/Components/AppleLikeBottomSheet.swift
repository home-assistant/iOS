import SwiftUI

public enum AppleLikeBottomSheetViewState {
    case initial
    case dismiss
}

private enum AppleLikeBottomSheetConstants {
    static let closebuttonSize: CGFloat = 30
}

public struct AppleLikeBottomSheet<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    /// Used for appear and disappear bottom sheet animation
    @State private var displayBottomSheet = false
    private let title: String?
    private let content: Content
    @State private var showCloseButton: Bool
    @Binding private var state: AppleLikeBottomSheetViewState?
    private let customDismiss: (() -> Void)?
    private let willDismiss: (() -> Void)?

    private let bottomSheetMinHeight: CGFloat
    private let contentInsets: EdgeInsets

    public init(
        title: String? = nil,
        @ViewBuilder content: () -> Content,
        contentInsets: EdgeInsets? = nil,
        bottomSheetMinHeight: CGFloat = 400,
        showCloseButton: Bool = true,
        state: Binding<AppleLikeBottomSheetViewState?>,
        customDismiss: (() -> Void)? = nil,
        willDismiss: (() -> Void)? = nil
    ) {
        self.title = title
        self.content = content()
        self.showCloseButton = showCloseButton
        self._state = state
        self.customDismiss = customDismiss
        self.willDismiss = willDismiss
        self.bottomSheetMinHeight = bottomSheetMinHeight
        self.contentInsets = contentInsets ?? EdgeInsets(
            top: .zero,
            leading: DesignSystem.Spaces.two,
            bottom: DesignSystem.Spaces.six,
            trailing: DesignSystem.Spaces.two
        )
    }

    public var body: some View {
        VStack {
            Spacer()
            bottomSheet
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.3))
        .modify {
            if #available(iOS 16, *) {
                $0.persistentSystemOverlays(.hidden)
            } else {
                $0
            }
        }
        .onChange(of: state) { newValue in
            if newValue == .dismiss {
                if #available(iOS 17.0, *) {
                    withAnimation(.bouncy) {
                        displayBottomSheet = false
                    } completion: {
                        performDismiss()
                    }
                } else {
                    withAnimation(.bouncy) {
                        displayBottomSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            performDismiss()
                        }
                    }
                }
            }
        }
    }

    private var bottomSheet: some View {
        VStack(spacing: .zero) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(contentInsets)
        }
        .padding(.horizontal)
        .frame(minHeight: bottomSheetMinHeight)
        .frame(maxWidth: maxWidth, alignment: .center)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: perfectCornerRadius))
        .shadow(color: .black.opacity(0.2), radius: 20)
        .padding(DesignSystem.Spaces.one)
        .fixedSize(horizontal: false, vertical: true)
        .offset(y: displayBottomSheet ? 0 : bottomSheetMinHeight)
        .onAppear {
            state = .initial
            withAnimation(.bouncy) {
                displayBottomSheet = true
            }
        }
    }

    private func performDismiss() {
        willDismiss?()
        if let customDismiss {
            customDismiss()
        } else {
            dismiss()
        }
    }

    private var maxWidth: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .phone {
            .infinity
        } else {
            400
        }
    }

    private var perfectCornerRadius: CGFloat {
        let cornerRadius: CGFloat = {
            if UIDevice.current.userInterfaceIdiom == .phone {
                return UIScreen.main.displayCornerRadius - DesignSystem.Spaces.one
            } else {
                return 50
            }
        }()
        let minimumCornerRadius = DesignSystem.CornerRadius.one
        return cornerRadius > minimumCornerRadius ? cornerRadius : minimumCornerRadius
    }

    @ViewBuilder
    private var header: some View {
        if showCloseButton || title != nil {
            VStack {
                HStack {
                    // Spacer reserved for title to be center properly
                    Rectangle()
                        .foregroundStyle(.clear)
                        .frame(
                            width: AppleLikeBottomSheetConstants.closebuttonSize,
                            height: AppleLikeBottomSheetConstants.closebuttonSize
                        )
                    Spacer()
                    if let title {
                        Text(title)
                            .font(DesignSystem.Font.title2.bold())
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                    Button(action: {
                        state = .dismiss
                    }, label: {
                        Image(systemSymbol: .xmarkCircleFill)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(
                                width: AppleLikeBottomSheetConstants.closebuttonSize,
                                height: AppleLikeBottomSheetConstants.closebuttonSize
                            )
                            .foregroundStyle(.gray, Color(uiColor: .secondarySystemBackground))
                    })
                }
            }
            .padding(.top, DesignSystem.Spaces.three)
            .padding(.horizontal, DesignSystem.Spaces.one)
        }
    }
}

#Preview("Allow notifications?") {
    AppleLikeBottomSheet(title: "Allow notifications?", content: {
        VStack(spacing: DesignSystem.Spaces.three) {
            Text(
                "Enable notifications and get what's happening in your home, from detecting leaks to doors left open, you have full control over what it tells you."
            )
            .foregroundStyle(.secondary)
            VStack(spacing: DesignSystem.Spaces.one) {
                Button {} label: {
                    Text("Allow notifications")
                }
                .buttonStyle(.primaryButton)
                Button {} label: {
                    Text("Do not allow")
                }
                .buttonStyle(.secondaryButton)
            }
        }
        .background(.green)
    }, contentInsets: .init(
        top: DesignSystem.Spaces.six,
        leading: DesignSystem.Spaces.two,
        bottom: DesignSystem.Spaces.half,
        trailing: DesignSystem.Spaces.two
    ), state: .constant(.initial), willDismiss: {})
}
