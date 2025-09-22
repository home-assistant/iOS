//
//  DynamicNotificationView.swift
//  WatchApp
//
//  Created by Bruno Pantaleão on 22/9/25.
//  Copyright © 2025 Home Assistant. All rights reserved.
//

import Foundation
import SwiftUI
import WatchKit
import MapKit
import Shared
import AVKit
import AVFoundation

struct DynamicNotificationView: View {
    @ObservedObject var viewModel: DynamicNotificationViewModel

    private let dynamicContentHeight: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
            textContent
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.leading)
            }
            dynamicContent
        }
    }

    @ViewBuilder
    private var textContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            if let title = viewModel.title, !title.isEmpty {
                Text(title)
                    .font(.headline)
            }
            if let subtitle = viewModel.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !viewModel.bodyText.isEmpty {
                Text(viewModel.bodyText)
                    .font(.body)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
    }

    private func errorMessage(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
            .padding(.top, 2)
    }

    @ViewBuilder
    private var dynamicContent: some View {
        if let dynamicContent = viewModel.dynamicContent {
            ZStack {
                switch dynamicContent {
                case .none:
                    EmptyView()
                case .image(let image):
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .map(let region, let pins):
                    if #available(watchOS 10.0, *) {
                        Map(position: .constant(.region(region))) {
                            // Draw pins, first in red, optional second in green
                            ForEach(Array(pins.enumerated()), id: \.offset) { index, pin in
                                Marker(pin.title ?? "", coordinate: pin.coordinate)
                                    .tint(index == 0 ? .red : .green)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: dynamicContentHeight)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.one))
                    } else {
                        Text("Map is only supported on watchOS 10+")
                    }
                case .video(let url):
                    VStack {
                        MovieView(movieURL: url)
                            .frame(maxWidth: .infinity)
                            .frame(height: dynamicContentHeight)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.one))
                    }
                case .mpegVideo:
                    Image(systemSymbol: .heart)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .error:
                    Text("Something went wrong...")
                }
                loader
            }
        }
    }

    @ViewBuilder
    private var loader: some View {
        if viewModel.isLoading {
            ProgressView()
                .progressViewStyle(.circular)
        }
    }
}

struct MovieView: WKInterfaceObjectRepresentable {
    var movieURL: URL

    func makeWKInterfaceObject(context: Context) -> WKInterfaceInlineMovie {
        .init()
    }

    func updateWKInterfaceObject(_ movie: WKInterfaceInlineMovie, context: Context) {
        movie.setLoops(true)
        movie.setMovieURL(movieURL)
        movie.playFromBeginning()
    }
}
