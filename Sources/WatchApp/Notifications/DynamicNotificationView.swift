import MapKit
import Shared
import SwiftUI

struct DynamicNotificationView: View {
    @ObservedObject var viewModel: DynamicNotificationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }

            switch viewModel.content {
            case let .image(image):
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
            case let .map(primary, secondary):
                let pins = [NotificationMapPin(coordinate: primary, tint: .red)] +
                    (secondary.map { [NotificationMapPin(coordinate: $0, tint: .green)] } ?? [])
                let region = secondary.map { MKCoordinateRegion(coordinates: [primary, $0]) }
                    ?? MKCoordinateRegion(
                        center: primary,
                        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    )
                Map(
                    coordinateRegion: .constant(region),
                    interactionModes: [],
                    annotationItems: pins
                ) { pin in
                    MapMarker(coordinate: pin.coordinate, tint: pin.tint)
                }
                .frame(height: 150)
            case let .movie(url):
                NotificationInlineMovieView(url: url)
                    .frame(height: 100)
            case nil:
                EmptyView()
            }

            if !viewModel.title.isEmpty {
                Text(viewModel.title)
                    .font(.headline)
            }

            if !viewModel.subtitle.isEmpty {
                Text(viewModel.subtitle)
                    .font(.headline)
            }

            if !viewModel.message.isEmpty {
                Text(viewModel.message)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    DynamicNotificationView(viewModel: DynamicNotificationViewModel())
}
