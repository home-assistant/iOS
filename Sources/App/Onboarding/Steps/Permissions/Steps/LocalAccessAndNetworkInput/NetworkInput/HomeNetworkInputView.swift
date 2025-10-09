//
//  HomeNetworkInputView.swift
//  App
//
//  Created by Bruno Pantaleão on 9/10/25.
//  Copyright © 2025 Home Assistant. All rights reserved.
//

import SwiftUI
import Shared

struct HomeNetworkInputView: View {
    @State private var networkName: String = ""
    @StateObject private var viewModel = HomeNetworkInputViewModel()

    let onNext: (String?) -> Void
    let onSkip: () -> Void

    var body: some View {
        BaseOnboardingView(
            illustration: {
                Image(.Onboarding.lock)
            },
            title: "Define your home network",
            primaryDescription: "Indicate when you're connected to your home network. This can be used to, for example, use the internal connection URL or disable the app lock when at home.",
            content: {
                VStack(spacing: DesignSystem.Spaces.two) {
                    // Network input field
                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                        Text("Wi-Fi network connected")
                            .font(DesignSystem.Font.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HATextField(placeholder: "Network name", text: $networkName)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    
                    HStack(alignment: .top, spacing: DesignSystem.Spaces.one) {
                        Image(systemSymbol: .infoCircleFill)
                            .foregroundStyle(.blue)
                            .font(.system(size: 20))
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                            Text("Make sure to set up your home network correctly.")
                                .font(DesignSystem.Font.body.weight(.medium))
                            
                            Text("Adding public Wi-Fi networks or using multiple ethernet/VPN connections may unintentionally expose information about or access to your app or server.")
                                .font(DesignSystem.Font.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(DesignSystem.Spaces.two)
                    .background(.blue.opacity(0.1))
                    .cornerRadius(DesignSystem.CornerRadius.three)
                }
                .frame(maxWidth: DesignSystem.List.rowMaxWidth)
                .padding(.top)
            },
            primaryActionTitle: "Next",
            primaryAction: {
                if networkName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    onNext(nil)
                } else {
                    onNext(networkName.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            },
            secondaryActionTitle: "Skip",
            secondaryAction: onSkip
        )
        .onAppear {
            loadCurrentNetworkInfo()
        }
        .onChange(of: viewModel.shouldComplete) { shouldComplete in
            if shouldComplete {
                onNext(networkName)
            }
        }
    }
    
    private func loadCurrentNetworkInfo() {
        Task {
            let networkInfo = await Current.networkInformation
            networkName = networkInfo?.ssid ?? ""
        }
    }
}

#Preview {
    NavigationView {
        HomeNetworkInputView(
            onNext: { networkName in
                print("Next tapped with network: \(networkName ?? "nil")")
            },
            onSkip: {
                print("Skip tapped")
            }
        )
        .navigationBarTitleDisplayMode(.inline)
    }
}

