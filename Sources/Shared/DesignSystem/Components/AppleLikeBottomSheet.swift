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

    private let bottomSheetMinHeight: CGFloat = 400

    public init(
        title: String? = nil,
        @ViewBuilder content: () -> Content,
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
    }

    public var body: some View {
        VStack {
            Spacer()
            ZStack(alignment: .top) {
                content
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, DesignSystem.Spaces.two)
                    .padding(.vertical, DesignSystem.Spaces.six)
                if showCloseButton {
                    closeButton
                }
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
        if UIDevice.current.userInterfaceIdiom == .phone {
            UIScreen.main.displayCornerRadius - DesignSystem.Spaces.one
        } else {
            50
        }
    }

    @ViewBuilder
    private var closeButton: some View {
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
            Spacer()
        }
        .padding(.top, DesignSystem.Spaces.three)
        .padding([.trailing, .bottom], DesignSystem.Spaces.one)
    }
}

#Preview {
    ZStack {
        VStack {}
            .background(.blue)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        AppleLikeBottomSheet(content: { Text("Hello World") }, state: .constant(.initial), willDismiss: {})
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
