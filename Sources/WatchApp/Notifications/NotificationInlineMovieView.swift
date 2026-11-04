import SwiftUI
import WatchKit

struct NotificationInlineMovieView: WKInterfaceObjectRepresentable {
    let url: URL

    final class Coordinator {
        var url: URL?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeWKInterfaceObject(context: Context) -> WKInterfaceInlineMovie {
        let movie = WKInterfaceInlineMovie()
        movie.setLoops(true)
        return movie
    }

    func updateWKInterfaceObject(_ wkInterfaceObject: WKInterfaceInlineMovie, context: Context) {
        guard context.coordinator.url != url else { return }
        context.coordinator.url = url
        wkInterfaceObject.setMovieURL(url)
        wkInterfaceObject.play()
    }
}

#Preview {
    NotificationInlineMovieView(url: URL(fileURLWithPath: "/dev/null"))
}
