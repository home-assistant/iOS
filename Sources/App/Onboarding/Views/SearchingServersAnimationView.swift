//
//  SearchingServersAnimationView.swift
//  App
//
//  Created by Bruno Pantaleão on 1/7/25.
//  Copyright © 2025 Home Assistant. All rights reserved.
//

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
            animateRotation()
        }
    }

    private var logo: some View {
        Image(.logoInCircle)
            .resizable()
            .frame(width: Constants.logoSize, height: Constants.logoSize)
            .scaleEffect(logoScale)
            .animation(.easeInOut(duration: Constants.logoPulseDuration).repeatForever(autoreverses: true), value: logoScale)
    }

    private var dots: some View {
        Image(.searchingServersDots)
            .resizable()
            .frame(width: Constants.dotsSize, height: Constants.dotsSize)
            .rotationEffect(.degrees(rotation))
    }

    private func animateRotation() {
        withAnimation(Animation.linear(duration: Constants.animationDuration)) {
            rotation += direction * Constants.rotationDegrees
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.animationDuration) {
            direction *= -1
            withAnimation(Animation.linear(duration: 0.01)) {
                rotation += direction * 0.01 // Small nudge to avoid abrupt stop
            }
            animateRotation()
        }
    }

    private func animateLogoPulse() {
        logoScale = Constants.logoPulseScale
    }
}

#Preview {
    SearchingServersAnimationView()
}
