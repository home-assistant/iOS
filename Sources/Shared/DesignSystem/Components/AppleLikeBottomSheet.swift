import SwiftUI

public enum AppleLikeBottomSheetViewState {
    case initial
    case dismiss
}

public struct AppleLikeBottomSheet<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    /// Used for appear and disappear bottom sheet animation
    @State private var displayBottomSheet = false
    private let content: Content
    @State private var showCloseButton: Bool
    @Binding private var state: AppleLikeBottomSheetViewState?
    private let willDismiss: (() -> Void)?

    private let bottomSheetMinHeight: CGFloat = 400

    public init(
        @ViewBuilder content: () -> Content,
        showCloseButton: Bool = true,
        state: Binding<AppleLikeBottomSheetViewState?>,
        willDismiss: (() -> Void)? = nil
    ) {
        self.content = content()
        self.showCloseButton = showCloseButton
        self._state = state
        self.willDismiss = willDismiss
    }

    public var body: some View {
        VStack {
            Spacer()
            ZStack(alignment: .top) {
                content
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Spaces.two)
                    .padding(.vertical, Spaces.six)
                if showCloseButton {
                    closeButton
                }
            }
            .padding(.horizontal)
            .frame(minHeight: bottomSheetMinHeight)
            .frame(maxWidth: maxWidth, alignment: .center)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: perfectCornerRadius))
            .shadow(color: .black.opacity(0.2), radius: 20)
            .padding(Spaces.one)
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
                        willDismiss?()
                        dismiss()
                    }
                } else {
                    withAnimation(.bouncy) {
                        displayBottomSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            willDismiss?()
                            dismiss()
                        }
                    }
                }
            }
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
            UIScreen.main.displayCornerRadius - Spaces.one
        } else {
            50
        }
    }

    @ViewBuilder
    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    state = .dismiss
                }, label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.gray, Color(uiColor: .tertiarySystemBackground))
                })
            }
            Spacer()
        }
        .padding(.top, Spaces.three)
        .padding([.trailing, .bottom], Spaces.one)
    }
}

#Preview {
    ZStack {
        VStack {}
            .background(.blue)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        AppleLikeBottomSheet(content: { Text("Hello World") }, state: .constant(.initial)) {}
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
