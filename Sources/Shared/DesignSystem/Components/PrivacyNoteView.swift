import SwiftUI

/// View used to display and highlight privacy related information
public struct PrivacyNoteView: View {
    @State private var background: AnyView
    @State private var startPoint: UnitPoint = .topLeading
    @State private var endPoint: UnitPoint = .bottomTrailing
    @State private var timer: Timer?

    let cornerRadius: CGFloat = 10
    let content: String

    public init(content: String) {
        self.content = content

        self.background = AnyView(
            LinearGradient(
                colors: [.purple, .blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    public var body: some View {
        VStack(spacing: Spaces.one) {
            Text(L10n.privacyLabel)
                .font(.caption.bold())
                .padding(.horizontal, Spaces.one)
                .padding(.vertical, Spaces.half)
                .background(.regularMaterial)
                .foregroundStyle(.gray)
                .clipShape(Capsule())
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: content)
                .font(.caption)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.gray)
        }
        .padding(Spaces.one)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .shadow(color: Color(uiColor: .label).opacity(0.2), radius: 5)
        .padding(.top)
        .onAppear {
            reverse()
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            reverse()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func reverse() {
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
                    material
                })
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
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

    private var material: some View {
        VStack {}
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.thickMaterial)
    }
}

#Preview {
    PrivacyNoteView(
        content: "This is a privacy note. It contains important information about your data and how it is used."
    )
    .padding()
}
