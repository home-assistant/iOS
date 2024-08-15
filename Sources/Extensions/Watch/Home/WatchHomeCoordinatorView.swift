//
//  WatchHomeCoordinatorView.swift
//  WatchExtension-Watch
//
//  Created by Bruno Pantaleão on 15/08/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import SwiftUI
import Shared

struct WatchHomeCoordinatorView: View {
    @StateObject private var viewModel = WatchHomeCoordinatorViewModel()

    init() {
        MaterialDesignIcons.register()
    }

    var body: some View {
        navigation
            .onAppear {
                viewModel.initialRoutine()
            }
    }

    @ViewBuilder
    private var navigation: some View {
        if #available(watchOS 10, *) {
            NavigationStack {
                content
            }
        } else {
            NavigationView {
                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.homeType {
        case .undefined:
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(2)
        case .legacy:
            LegacyWatchHomeView(viewModel: LegacyWatchHomeViewModel())
        case let .config(watchConfig, magicItemsInfo):
            WatchHomeView(watchConfig: watchConfig, magicItemsInfo: magicItemsInfo)
        }
    }
}

#Preview {
    WatchHomeCoordinatorView()
}
