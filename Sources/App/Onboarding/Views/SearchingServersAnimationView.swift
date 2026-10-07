import Shared
import SwiftUI

struct SearchingServersAnimationView: View {
    enum Constants {
        static let dotsSize: CGFloat = 200
        static let logoSize: CGFloat = 80
        static let rotationDegrees: Double = 360
        static let animationDuration: Double = 5
        static let logoPulseScale: CGFloat = 1.15
        static let logoPulseDuration: Double = 0.8
        static let secondsUntilShowText: CGFloat = 8
        static let minimumScale: CGFloat = 0.4
    }

    @State private var rotation: Double = 0
    @State private var direction: Double = 1
    @State private var logoScale: CGFloat = 1.0
    @State private var showText: Bool = false

    let text: String?
    /// Height the whole animation may take. The dots and logo shrink to what is left beside the
    /// text once it shows; the text keeps its size so it stays legible.
    let availableHeight: CGFloat?
    @State private var textHeight: CGFloat = 0

    init(text: String? = nil, availableHeight: CGFloat? = nil) {
        self.text = text
        self.availableHeight = availableHeight
    }

    /// Ratio the dots and logo are drawn at so the measured text and the spacing still fit.
    private var scale: CGFloat {
        guard let availableHeight, availableHeight > 0 else { return 1 }
        let heightForDots = availableHeight - textHeight - DesignSystem.Spaces.three
        return min(1, max(Constants.minimumScale, heightForDots / Constants.dotsSize))
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.three) {
            ZStack {
                dots
                logo
            }

            Text(text ?? "")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(height: showText ? nil : 0)
                .frame(width: showText ? nil : 0)
                .opacity(showText ? 1 : 0)
                .animation(.easeInOut, value: showText)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    textHeight = height
                }
        }
        .onAppear {
            animateLogoPulse()
            withAnimation(Animation.linear(duration: Constants.animationDuration).repeatForever(autoreverses: false)) {
                rotation = direction * Constants.rotationDegrees
            }
            if text != nil {
                scheduleText()
            }
        }
        .onDisappear {
            rotation = 0
        }
    }

    private func scheduleText() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.secondsUntilShowText) {
            withAnimation {
                showText = true
            }
        }
    }

    private var logo: some View {
        Image(.logoInCircle)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(logoScale, anchor: .center)
            .frame(width: Constants.logoSize * scale, height: Constants.logoSize * scale)
    }

    private var dots: some View {
        Image(.searchingServersDots)
            .resizable()
            .frame(width: Constants.dotsSize * scale, height: Constants.dotsSize * scale)
            .rotationEffect(.degrees(rotation))
    }

    private func animateLogoPulse() {
        withAnimation(Animation.easeInOut(duration: Constants.logoPulseDuration).repeatForever(autoreverses: true)) {
            logoScale = Constants.logoPulseScale
        }
    }
}

#Preview {
    ZStack {
        List {
            Text("Example")
        }
        SearchingServersAnimationView(
            text: "Check that your Home Assistant is powered on and you're connected to the same network. You can enter the address manually if you know it."
        )
    }
}
