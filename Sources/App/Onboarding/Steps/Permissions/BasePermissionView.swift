//
//  BasePermissionView.swift
//  App
//
//  Created by Bruno Pantaleão on 16/9/25.
//  Copyright © 2025 Home Assistant. All rights reserved.
//

import SwiftUI
import Shared

/// A reusable screen scaffold for permission-style pages:
/// - Illustration at the top
/// - Big, centered title
/// - One or two body paragraphs
/// - Optional developer-injected content below the description
/// - Optional list of selectable choices (radio-style)
/// - Optional informational callout below choices
/// - Bottom area with primary button and optional secondary button
public struct BasePermissionView<Illustration: View, Content: View>: View {
    // MARK: - Inputs

    private let illustration: () -> Illustration
    private let title: LocalizedStringKey
    private let primaryDescription: LocalizedStringKey
    private let secondaryDescription: LocalizedStringKey?

    // Optional injected content placed below the secondary description
    private let content: (() -> Content)?

    private let primaryActionTitle: LocalizedStringKey
    private let primaryAction: () -> Void

    private let secondaryActionTitle: LocalizedStringKey?
    private let secondaryAction: (() -> Void)?

    // Layout tuning
    private let verticalSpacing: CGFloat
    private let maxContentWidth: CGFloat = Sizes.maxWidthForLargerScreens


    // MARK: - Inits

    /// Iinitializer that accepts custom content below the descriptions.
    public init(
        @ViewBuilder illustration: @escaping () -> Illustration,
        title: LocalizedStringKey,
        primaryDescription: LocalizedStringKey,
        secondaryDescription: LocalizedStringKey? = nil,
        @ViewBuilder content: @escaping () -> Content,
        primaryActionTitle: LocalizedStringKey,
        primaryAction: @escaping () -> Void,
        secondaryActionTitle: LocalizedStringKey? = nil,
        secondaryAction: (() -> Void)? = nil,
        illustrationTopPadding: CGFloat = DesignSystem.Spaces.four,
        verticalSpacing: CGFloat = DesignSystem.Spaces.three
    ) {
        self.illustration = illustration
        self.title = title
        self.primaryDescription = primaryDescription
        self.secondaryDescription = secondaryDescription
        self.content = content
        self.primaryActionTitle = primaryActionTitle
        self.primaryAction = primaryAction
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryAction = secondaryAction
        self.verticalSpacing = verticalSpacing
    }

    /// No custom content initializer.
    public init(
        @ViewBuilder illustration: @escaping () -> Illustration,
        title: LocalizedStringKey,
        primaryDescription: LocalizedStringKey,
        secondaryDescription: LocalizedStringKey? = nil,
        primaryActionTitle: LocalizedStringKey,
        primaryAction: @escaping () -> Void,
        secondaryActionTitle: LocalizedStringKey? = nil,
        secondaryAction: (() -> Void)? = nil,
        illustrationTopPadding: CGFloat = DesignSystem.Spaces.four,
        verticalSpacing: CGFloat = DesignSystem.Spaces.three
    ) where Content == EmptyView {
        self.illustration = illustration
        self.title = title
        self.primaryDescription = primaryDescription
        self.secondaryDescription = secondaryDescription
        self.content = nil
        self.primaryActionTitle = primaryActionTitle
        self.primaryAction = primaryAction
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryAction = secondaryAction
        self.verticalSpacing = verticalSpacing
    }

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(spacing: verticalSpacing) {
                Spacer(minLength: DesignSystem.Spaces.four)
                illustration()
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(title)
                    .font(DesignSystem.Font.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spaces.two)

                VStack(spacing: DesignSystem.Spaces.two) {
                    Text(primaryDescription)
                        .font(DesignSystem.Font.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if let secondaryDescription {
                        Text(secondaryDescription)
                            .font(DesignSystem.Font.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Injected content appears here, below the secondary description
                    if let content {
                        content()
                    }
                }
                .padding(.horizontal, DesignSystem.Spaces.two)

                Spacer(minLength: DesignSystem.Spaces.four)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .frame(maxWidth: maxContentWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            bottomActions
        }
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Bottom actions

    @ViewBuilder
    private var bottomActions: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            Button(action: primaryAction) {
                Text(primaryActionTitle)
            }
            .buttonStyle(.primaryButton)

            if let secondaryActionTitle, let secondaryAction {
                Button(action: secondaryAction) {
                    Text(secondaryActionTitle)
                }
                .buttonStyle(.secondaryButton)
                .tint(Color.haPrimary)
            }
        }
        .frame(maxWidth: Sizes.maxWidthForLargerScreens)
        .padding([.horizontal, .bottom], DesignSystem.Spaces.two)
        .background(Color(uiColor: .systemBackground).opacity(0.95))
    }
}

// MARK: - Previews

#Preview("Location permission example (simple)") {
    NavigationView {
        BasePermissionView(
            illustration: {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .frame(width: 120, height: 120)
                    .foregroundStyle(.secondary)
                    .overlay(
                        Text("Illustration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    )
                    .padding(.top, DesignSystem.Spaces.four)
            },
            title: "Use this device's location for automations",
            primaryDescription: "Location sharing enables powerful automations, such as turning off the heating when you leave home. This option shares the device’s location only with your Home Assistant system.",
            secondaryDescription: "This data stays in your home and is never sent to third parties. It also helps strengthen the security of your connection to Home Assistant.",
            primaryActionTitle: "Share my location",
            primaryAction: {},
            secondaryActionTitle: "Do not share my location",
            secondaryAction: {}
        )
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("With injected content") {
    NavigationView {
        BasePermissionView(
            illustration: {
                Image(systemName: "location.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .foregroundStyle(.secondary)
                    .padding(.top, DesignSystem.Spaces.four)
            },
            title: "Use this device's location for automations",
            primaryDescription: "Location sharing enables powerful automations.",
            secondaryDescription: "This data stays in your home and is never sent to third parties.",
            content: {
                VStack(spacing: DesignSystem.Spaces.one) {
                    Toggle(isOn: .constant(true)) {
                        Text("Also share precise location")
                    }
                    .toggleStyle(.switch)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("You can change this later in Settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: DesignSystem.List.rowMaxWidth)
            },
            primaryActionTitle: "Share my location",
            primaryAction: {},
            secondaryActionTitle: "Do not share my location",
            secondaryAction: {}
        )
        .navigationBarTitleDisplayMode(.inline)
    }
}
