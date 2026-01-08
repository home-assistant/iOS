import SwiftUI

/// View used to display and highlight privacy related information
public struct PrivacyNoteView: View {
    @State private var startPoint: UnitPoint = .topLeading
    @State private var endPoint: UnitPoint = .bottomTrailing
    @State private var timer: Timer?
    @State private var background: AnyView = .init(
        LinearGradient(
            colors: [.purple, .blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(content: {
            ThickMaterialOverlay()
        })
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndMicro))
    )

    private let content: String
    private let animating: Bool

    public init(content: String, animating: Bool = true) {
        self.content = content
        self.animating = animating
    }

    public var body: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            Text(L10n.privacyLabel)
                .font(.caption.bold())
                .padding(.horizontal, DesignSystem.Spaces.one)
                .padding(.vertical, DesignSystem.Spaces.half)
                .background(.thickMaterial)
                .foregroundStyle(.gray)
                .clipShape(Capsule())
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.caption)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.gray)
        }
        .padding(DesignSystem.Spaces.one)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndMicro))
        .shadow(color: Color(uiColor: .label).opacity(0.2), radius: 5)
        .padding(.top)
        .onAppear {
            if animating {
                rotareLinearBackgroundPointsForBackgroundAnimation()
                startTimer()
            }
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            rotareLinearBackgroundPointsForBackgroundAnimation()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func rotareLinearBackgroundPointsForBackgroundAnimation() {
        startPoint = rotatePoint(startPoint)
        endPoint = rotatePoint(endPoint)
        withAnimation(.easeIn(duration: 2)) {
            background = AnyView(
                LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: startPoint,
                    endPoint: endPoint
                )
                .overlay(content: {
                    ThickMaterialOverlay()
                })
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndMicro))
            )
        }
    }

    private func rotatePoint(_ point: UnitPoint) -> UnitPoint {
        switch point {
        case .topLeading:
            return .top
        case .top:
            return .topTrailing
        case .topTrailing:
            return .trailing
        case .trailing:
            return .bottomTrailing
        case .bottomTrailing:
            return .bottom
        case .bottom:
            return .bottomLeading
        case .bottomLeading:
            return .leading
        case .leading:
            return .topLeading
        default:
            return .topLeading
        }
    }
}

struct ThickMaterialOverlay: View {
    var body: some View {
        VStack {}
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.thickMaterial)
    }
}

#Preview {
    VStack {
        PrivacyNoteView(
            content: "This is a privacy note. It contains important information about your data and how it is used."
        )
        .padding()
        PrivacyNoteView(
            content: "This is a privacy note. It contains important information about your data and how it is used.",
            animating: false
        )
        .padding()
    }
}
