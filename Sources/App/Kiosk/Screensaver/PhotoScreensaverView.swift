import Combine
import Photos
import Shared
import SwiftUI

// MARK: - Photo Screensaver View

/// A screensaver view that displays photos with smooth transitions
public struct PhotoScreensaverView: View {
    @ObservedObject private var manager = KioskModeManager.shared
    @ObservedObject private var photoManager = PhotoManager.shared

    @State private var currentImage: UIImage?
    @State private var nextImage: UIImage?
    @State private var showingNext: Bool = false
    @State private var pixelShiftOffset: CGSize = .zero

    private let showClock: Bool
    private let screenSize = UIScreen.main.bounds.size

    public init(showClock: Bool = false) {
        self.showClock = showClock
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .edgesIgnoringSafeArea(.all)

                // Photo display with crossfade transition
                photoContent(size: geometry.size)
                    .offset(pixelShiftOffset)

                // Optional clock overlay
                if showClock {
                    clockOverlay
                        .offset(pixelShiftOffset)
                }

                // Loading indicator
                if photoManager.isLoading && currentImage == nil {
                    loadingView
                }

                // Error message
                if let error = photoManager.errorMessage, currentImage == nil {
                    errorView(error)
                }

                // Photo access request
                if photoManager.authorizationStatus == .notDetermined {
                    accessRequestView
                }
            }
        }
        .onAppear {
            startPhotoDisplay()
        }
        .onDisappear {
            stopPhotoDisplay()
        }
        .onReceive(photoManager.$currentIndex) { _ in
            loadCurrentPhoto()
        }
        .onReceive(NotificationCenter.default.publisher(for: .kioskPixelShiftTick)) { _ in
            applyPixelShift()
        }
    }

    // MARK: - Photo Content

    @ViewBuilder
    private func photoContent(size: CGSize) -> some View {
        ZStack {
            // Current image
            if let image = currentImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: manager.settings.photoFitMode == .fill ? .fill : .fit)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .opacity(showingNext ? 0 : 1)
                    .animation(.easeInOut(duration: 1.0), value: showingNext)
            }

            // Next image (for crossfade)
            if let image = nextImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: manager.settings.photoFitMode == .fill ? .fill : .fit)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .opacity(showingNext ? 1 : 0)
                    .animation(.easeInOut(duration: 1.0), value: showingNext)
            }
        }
    }

    // MARK: - Clock Overlay

    private var clockOverlay: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(timeString)
                        .font(.system(size: 48, weight: .light, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)

                    if manager.settings.clockShowDate {
                        Text(dateString)
                            .font(.system(size: 18, weight: .light, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial.opacity(0.3))
                )
                .padding(32)
            }
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text("Loading photos...")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.6))

            Text(message)
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))

            Text("Configure photo sources in kiosk settings")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Access Request View

    private var accessRequestView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.8))

            Text("Photo Access Required")
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)

            Text("The app needs access to your photos to display them as a screensaver.")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                Task {
                    if await photoManager.requestAccess() {
                        photoManager.loadPhotos()
                    }
                }
            } label: {
                Text("Grant Access")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(10)
            }
        }
    }

    // MARK: - Photo Management

    private func startPhotoDisplay() {
        photoManager.loadPhotos()
        photoManager.startRotation()
    }

    private func stopPhotoDisplay() {
        photoManager.stopRotation()
    }

    private func loadCurrentPhoto() {
        guard let photo = photoManager.currentPhoto else { return }

        Task {
            let image = await photo.loadImage(targetSize: screenSize)

            // Crossfade transition
            if currentImage != nil {
                nextImage = image
                withAnimation {
                    showingNext = true
                }

                // After animation completes, swap images
                try? await Task.sleep(nanoseconds: 1_100_000_000) // 1.1 seconds
                currentImage = image
                nextImage = nil
                showingNext = false
            } else {
                currentImage = image
            }
        }
    }

    // MARK: - Pixel Shift

    private func applyPixelShift() {
        guard manager.settings.pixelShiftEnabled else { return }

        let amount = manager.settings.pixelShiftAmount

        withAnimation(.easeInOut(duration: 1.0)) {
            pixelShiftOffset = CGSize(
                width: CGFloat.random(in: -amount...amount),
                height: CGFloat.random(in: -amount...amount)
            )
        }
    }
}

// MARK: - Preview

#Preview("Photo Screensaver") {
    PhotoScreensaverView(showClock: false)
}

#Preview("Photo with Clock") {
    PhotoScreensaverView(showClock: true)
}
