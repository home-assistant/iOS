//
//  CardView.swift
//  App
//
//  Created by Bruno Pantaleão on 24/11/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import SwiftUI

@available(iOS 13, *)
public struct CardView<Content: View>: View {
    public let content: () -> Content
    public let backgroundColor: Color?

    public init(backgroundColor: Color? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.backgroundColor = backgroundColor
        self.content = content
    }

    public var body: some View {
        VStack(spacing: .zero) {
            content()
                .padding()
        }
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
        /* Corner radius is duplicated to assure even with a background color it will
         keep the corner radius */
        .cornerRadius(HACornerRadius.standard)
        .overlay(
            RoundedRectangle(cornerRadius: HACornerRadius.standard)
                .stroke(
                    Color(Asset.Colors.onSurface.name), lineWidth: 1)
        )
    }
}

@available(iOS 13, *)
#Preview {
    VStack {
        CardView {
            Text("abc")
        }
        .padding()
    }
    .background(Color.yellow)
}
