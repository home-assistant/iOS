import SwiftUI

struct SearchingServersAnimationView: View {
    enum Constants {
        static let dotsSize: CGFloat = 200
        static let logoSize: CGFloat = 80
        static let rotationDegrees: Double = 360
        static let animationDuration: Double = 5
        static let logoPulseScale: CGFloat = 1.15
        static let logoPulseDuration: Double = 0.8
    }

    @State private var rotation: Double = 0
    @State private var direction: Double = 1
    @State private var logoScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            dots
            logo
        }
        .onAppear {
            animateLogoPulse()
            withAnimation(Animation.linear(duration: Constants.animationDuration).repeatForever(autoreverses: false)) {
                rotation = direction * Constants.rotationDegrees
            }
        }
        .onDisappear {
            rotation = 0
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
        SearchingServersAnimationView()
    }
}
