import AVFoundation
import AVKit
import MapKit
import PromiseKit
import Shared
import SwiftUI
import UserNotifications

struct DynamicNotificationView: View {
    @ObservedObject var viewModel: DynamicNotificationViewModel

    @State private var player = AVPlayer()
    private let dynamicContentHeight: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
            // Dynamic content is presented first to align with watchOS default notification style
            dynamicContentView
            textContent
            loader
            errorView
        }
    }

    @ViewBuilder
    private var dynamicContentView: some View {
        switch viewModel.content {
        case .none:
            EmptyView()
        case let .image(image):
            imageView(image: image)
        case let .video(url):
            videoPlayer(url: url)
        case let .map(region, pins):
            mapView(region, pins)
        }
    }

    @ViewBuilder
    private var errorView: some View {
        if let error = viewModel.errorMessage, !error.isEmpty {
            Text(error)
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var loader: some View {
        if viewModel.isLoading {
            HStack {
                Spacer()
                ProgressView().progressViewStyle(.circular)
                Spacer()
            }
        }
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: .zero) {
            if !viewModel.title.isEmpty {
                Text(viewModel.title)
                    .font(.headline)
            }
            if !viewModel.subtitle.isEmpty {
                Text(viewModel.subtitle)
                    .font(.headline)
            }
            if !viewModel.body.isEmpty {
                Text(viewModel.body)
                    .font(.body)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
    }

    private func imageView(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func videoPlayer(url: URL) -> some View {
        VideoPlayer(player: player)
            .frame(maxWidth: .infinity)
            .frame(height: dynamicContentHeight)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.one))
            .onAppear {
                // Build a new item each time we appear and autoplay shortly after.
                let item = AVPlayerItem(url: url)
                player.replaceCurrentItem(with: item)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    player.play()
                }
            }
            .onDisappear {
                // Release the item so file handles are closed; the view model owns security-scope.
                player.pause()
                player.replaceCurrentItem(with: nil)
            }
    }

    private func mapView(_ region: MKCoordinateRegion, _ pins: [CLLocationCoordinate2D]) -> some View {
        Map(coordinateRegion: .constant(region), annotationItems: pins.enumerated().map { idx, coord in
            IdentifiedCoordinate(id: idx, coordinate: coord)
        }) { pin in
            MapMarker(coordinate: pin.coordinate, tint: pin.id == 0 ? .red : .green)
        }
        .frame(maxWidth: .infinity)
        .frame(height: dynamicContentHeight)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.one))
    }

    private struct IdentifiedCoordinate: Identifiable {
        let id: Int
        let coordinate: CLLocationCoordinate2D
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
