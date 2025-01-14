//
//  WidgetBuilderView.swift
//  App
//
//  Created by Bruno Pantaleão on 13/1/25.
//  Copyright © 2025 Home Assistant. All rights reserved.
//

import SwiftUI

struct WidgetBuilderView: View {
    @State private var showAddWidget = false

    var body: some View {
        List {
            Section("Your widgets") {
                Button(action: {
                    showAddWidget = true
                }) {
                    Label("Add widget", systemSymbol: .plus)
                }
            }
        }
        .sheet(isPresented: $showAddWidget, content: {
            WidgetCreationView()
        })
        .navigationTitle("Widgets")
    }
}

#Preview {
    NavigationView {
        WidgetBuilderView()
    }
}
