//
//  WidgetCreationView.swift
//  App
//
//  Created by Bruno Pantaleão on 13/1/25.
//  Copyright © 2025 Home Assistant. All rights reserved.
//

import SwiftUI
import Shared

struct WidgetCreationView: View {
    @State private var showAddItem = false

    var body: some View {
        ScrollView {
            VStack {
                VStack {
                    LazyVGrid(columns: [GridItem(), GridItem()]) {
                        addPlaceholderTile
                        ForEach(0..<9) { index in
                            placeholderCard()
                        }
                    }
                    .padding(Spaces.one)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .background(Color.asset(Asset.Colors.primaryBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.2), radius: 10)
                .padding()
            }
        }
        .navigationTitle("Create widget")
        .sheet(isPresented: $showAddItem) {
            MagicItemAddView(context: .widget) { magicItem in
                
            }
        }
    }

    private func placeholderCard() -> some View {
        TileCard(content: .init(title: "", subtitle: "", image: Image(systemSymbol: .dotSquare)))
    }

    private var addPlaceholderTile: some View {
        TileCard(content: .init(title: "Add item", subtitle: nil, image: Image(systemSymbol: .plus)))
            .onTapGesture {
                showAddItem = true
            }
    }
}

#Preview {
    NavigationView {
        WidgetCreationView()
    }
}
