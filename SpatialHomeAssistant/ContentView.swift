//
//  ContentView.swift
//  SpatialHomeAssistant
//
//  Created by Bruno Pantaleão on 19/01/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationSplitView(sidebar: {
                List {
                    Section("Domains") {
                        Group {
                            Text("Buttons")
                            Text("Covers")
                            Text("Locks")
                            Text("Contact Sensors")
                        }
                        .hoverEffect()
                    }
                }
                .navigationTitle("Home Assistant")
            }, detail: {
                HStack {
                    someItem
                    someItem
                    someItem
                    someItem
                    someItem
                }
                HStack {
                    someItem
                    someItem
                    someItem
                    someItem
                    someItem
                }
                HStack {
                    someItem
                    someItem
                    someItem
                    someItem
                    someItem
                }
                HStack {
                    someItem
                    someItem
                    someItem
                    someItem
                    someItem
                }
            })
            .tabItem {
                Image(systemName: "house")
            }
        }
    }

    private var someItem: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock")
            Text("Door lock")
        }
        .padding()
        .background(Material.regular)
        .cornerRadius(20)
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
