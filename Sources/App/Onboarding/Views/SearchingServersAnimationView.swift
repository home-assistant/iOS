import SwiftUI
import Shared
struct SearchingServersAnimationView: View {
    enum Constants {
        static let dotsSize: CGFloat = 200
        static let logoSize: CGFloat = 80
        static let rotationDegrees: Double = 360
        static let animationDuration: Double = 5
        static let logoPulseScale: CGFloat = 1.15
        static let logoPulseDuration: Double = 0.8
        static let secondsUntilShowText: CGFloat = 8
    }

    @State private var rotation: Double = 0
    @State private var direction: Double = 1
    @State private var logoScale: CGFloat = 1.0
    @State private var showText: Bool = false

    let text: String?

    init(text: String? = nil) {
        self.text = text
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
            .frame(width: Constants.logoSize, height: Constants.logoSize)
    }

    private var dots: some View {
        Image(.searchingServersDots)
            .resizable()
            .frame(width: Constants.dotsSize, height: Constants.dotsSize)
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
        SearchingServersAnimationView(text: "Check that your Home Assistant is powered on and you're connected to the same network. You can enter the address manually if you know it.")
    }
}
