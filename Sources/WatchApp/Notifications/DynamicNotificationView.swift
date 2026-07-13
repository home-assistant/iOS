import MapKit
import Shared
import SwiftUI

struct DynamicNotificationView: View {
    @ObservedObject var viewModel: DynamicNotificationViewModel
    private let attachmentCornerRadius: CGFloat = DesignSystem.CornerRadius.oneAndHalf
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
                    .clipShape(RoundedRectangle(cornerRadius: attachmentCornerRadius))
            case let .map(primary, secondary):
                let pins = [NotificationMapPin(id: "primary", coordinate: primary, tint: .red)] +
                    (secondary.map { [NotificationMapPin(id: "secondary", coordinate: $0, tint: .green)] } ?? [])
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
                .clipShape(RoundedRectangle(cornerRadius: attachmentCornerRadius))
            case let .movie(url):
                NotificationInlineMovieView(url: url)
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: attachmentCornerRadius))
            case nil:
                EmptyView()
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spaces.micro) {
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, -DesignSystem.Spaces.one) // Hack to remove extra padding in the custom notifications view
    }
}

#Preview("Text") {
    DynamicNotificationView(viewModel: .preview(
        title: "Garage door",
        message: "The garage door has been open for 10 minutes"
    ))
}

#Preview("Map") {
    DynamicNotificationView(viewModel: .preview(
        title: "Location update",
        message: "Bruno arrived home",
        content: .map(
            primary: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            secondary: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094)
        )
    ))
}

#Preview("Image") {
    DynamicNotificationView(viewModel: .preview(
        title: "Doorbell",
        message: "Someone is at the door",
        content: .image({
            UIGraphicsBeginImageContextWithOptions(CGSize(width: 320, height: 180), true, 1)
            defer { UIGraphicsEndImageContext() }
            UIColor.cyan.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 320, height: 180))
            UIColor.yellow.setFill()
            UIRectFill(CGRect(x: 120, y: 50, width: 80, height: 80))
            return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        }())
    ))
}
