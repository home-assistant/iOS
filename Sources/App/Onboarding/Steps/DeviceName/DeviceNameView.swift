//
//  DeviceNameView.swift
//  App
//
//  Created by Bruno Pantaleão on 8/7/25.
//  Copyright © 2025 Home Assistant. All rights reserved.
//

import SwiftUI
import Shared
import SFSafeSymbols

struct DeviceNameView: View {

    @State private var deviceName: String = UIDevice.current.name

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spaces.three) {
                Image(systemSymbol: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .foregroundStyle(.haPrimary)
                Text(L10n.DeviceName.title)
                    .font(DesignSystem.Font.largeTitle.bold())
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                Text(L10n.DeviceName.subtitle)
                    .font(DesignSystem.Font.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                HATextField(placeholder: L10n.DeviceName.Textfield.placeholder, text: $deviceName)
            }
            .padding(DesignSystem.Spaces.two)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                // TODO: send name to Home Assistant
            } label: {
                Text(L10n.DeviceName.PrimaryButton.title)
            }
            .buttonStyle(.primaryButton)
            .padding(DesignSystem.Spaces.two)

        }
    }

    private var icon: SFSymbol {
        if #available(iOS 16.1, *) {
            .macbookAndIphone
        } else {
            .iphone
        }
    }
}

#Preview {
    DeviceNameView()
}
