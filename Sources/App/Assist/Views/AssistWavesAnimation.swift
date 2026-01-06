import SwiftUI

struct AssistWavesAnimation: View {
    @State private var animationPhase: CGFloat = 0

    @State private var circle1Size: CGFloat = 50
    @State private var circle2Size: CGFloat = 50
    @State private var circle3Size: CGFloat = 50
    @State private var circle4Size: CGFloat = 50

    var body: some View {
        HStack(spacing: .zero) {
            RoundedRectangle(cornerRadius: 20)
                .fill(.blue)
                .frame(maxWidth: .infinity)
                .frame(height: circle1Size)
            RoundedRectangle(cornerRadius: 20)
                .fill(.cyan)
                .frame(maxWidth: .infinity)
                .frame(height: circle2Size)
            RoundedRectangle(cornerRadius: 20)
                .fill(.blue.opacity(0.8))
                .frame(maxWidth: .infinity)
                .frame(height: circle3Size)
            RoundedRectangle(cornerRadius: 20)
                .fill(.teal)
                .frame(maxWidth: .infinity)
                .frame(height: circle4Size)
        }
        .blur(radius: 50)
        .onAppear {
            startWaveAnimation()
        }
    }

    private func startWaveAnimation() {
        // Create staggered wave animations for each bar
        withAnimation(.easeInOut(duration: 0.2).repeatForever(autoreverses: true).delay(0.8)) {
            circle1Size = 35
        }

        withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true).delay(0.5)) {
            circle2Size = 150
        }

        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.4)) {
            circle3Size = 80
        }

        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.3)) {
            circle4Size = 70
        }
    }
}

#Preview {
    VStack {
        Spacer()
        AssistWavesAnimation()
    }
}

#Preview("Dark") {
    VStack {
        Spacer()
        AssistWavesAnimation()
    }
    .preferredColorScheme(.dark)
}
