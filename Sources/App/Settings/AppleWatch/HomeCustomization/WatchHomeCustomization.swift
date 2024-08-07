//
//  WatchHomeCustomization.swift
//  App
//
//  Created by Bruno Pantaleão on 07/08/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import SwiftUI
import Shared

struct WatchHomeCustomization: View {
    @StateObject private var viewModel = WatchHomeCustomizationViewModel()

    var body: some View {
        List {
            watchPreview
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
                .onAppear {
                    viewModel.loadWatchConfig()
                }
            Section {
                Toggle(isOn: $viewModel.watchConfig.showAssist, label: {
                    Text("Show Assist")
                })
            }
            Section {
                ForEach(viewModel.watchConfig.items, id: \.id) { item in
                    makeListItem(item: item)
                }
                Button {
                    //
                } label: {
                    Label("Add item", systemImage: "plus")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var watchPreview: some View {
        ZStack {
            watchItemsList
                .offset(x: -10)
            Image(systemName: "applewatch.case.inset.filled")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 260)
                .foregroundStyle(.clear, Color(hue: 0, saturation: 0, brightness: 0.2))
        }
    }

    private var watchItemsList: some View {
        ZStack(alignment: .top) {
            List {
                VStack {}.padding(.top, 40)
                ForEach(viewModel.watchConfig.items, id: \.id) { item in
                    makeWatchItem(item: item)
                }
                if viewModel.watchConfig.items.isEmpty {
                    noItemsWatchView
                }
            }
            .listStyle(.plain)
            .frame(width: 195, height: 235)
            watchStatusBar
        }
    }

    private func makeListItem(item: WatchItem) -> some View {
        var name: String = ""
        var iconName: String = ""
        switch item.type {
        case .action(let action):
            name = action.name
            iconName = action.iconName
        case .script(let script):
            name = script.name ?? "Unknown Script"
            iconName = script.iconName ?? ""
        }

        return makeListItemRow(iconName: iconName, name: name)
    }

    private func makeListItemRow(iconName: String?, name: String) -> some View {
        Text(name)
    }

    private func makeWatchItem(item: WatchItem) -> some View {
        var name: String = ""
        var iconName: String = ""
        var iconColor: String? = "#ffffff"
        switch item.type {
        case .action(let action):
            name = action.name
            iconName = action.iconName
        case .script(let script):
            name = script.name ?? "Unknown Script"
            iconName = script.iconName ?? ""
        }

        return HStack(spacing: Spaces.one) {
            VStack {
                Image(uiImage: MaterialDesignIcons.headIcon.image(
                    ofSize: .init(width: 24, height: 24),
                    color: .init(hex: iconColor)
                ))
                .foregroundColor(Color(uiColor: .init(hex: iconColor)))
                .padding(Spaces.one)
            }
            .background(Color(uiColor: .init(hex: iconColor)).opacity(0.3))
            .clipShape(Circle())
            Text(name)
                .font(.system(size: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spaces.one)
        .frame(width: 190, height: 55)
        .background(.gray.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.vertical, -Spaces.one)
    }

    private var watchStatusBar: some View {
        ZStack(alignment: .trailing) {
            Text("9:41")
                .font(.system(size: 14).bold())
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top)
            Image(uiImage: MaterialDesignIcons.messageProcessingOutlineIcon.image(ofSize: .init(width: 18, height: 18), color: Asset.Colors.haPrimary.color))
                .padding(Spaces.one)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 25.0))
                .offset(x: -22)
                .padding(.top)
        }
        .frame(width: 210, height: 50)
        .background(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
    }

    private var noItemsWatchView: some View {
        Text(L10n.Watch.Settings.NoItems.Phone.title)
            .frame(maxWidth: .infinity, alignment: .center)
            .font(.footnote)
            .padding(Spaces.one)
            .background(.gray.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

}

#Preview {
    NavigationView {
        WatchHomeCustomization()
    }
}
