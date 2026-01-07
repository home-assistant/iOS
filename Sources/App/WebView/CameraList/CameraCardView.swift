import Shared
import SwiftUI

struct CameraCardView: View {
    @StateObject private var viewModel: CameraCardViewModel

    init(serverId: String, entityId: String) {
        self._viewModel = .init(wrappedValue: CameraCardViewModel(serverId: serverId, entityId: entityId))
    }

    var body: some View {
        VStack {
            ZStack {
                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                reloadButtonOverlay
                timestampOverlay
            }
        }
        .background(.black)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.two))
        .onAppear {
            viewModel.viewDidAppear()
        }
        .onDisappear {
            viewModel.viewDidDisappear()
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if let image = viewModel.image {
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if let errorMessage = viewModel.errorMessage {
            errorView(message: errorMessage)
        } else if viewModel.isLoading {
            loadingView
        } else {
            Rectangle()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            Image(systemSymbol: .exclamationmarkTriangleFill)
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .modifier(GlassBackgroundModifier())
        }
    }

    private var loadingView: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .tint(.white)
            .scaleEffect(1.5)
    }

    private var reloadButtonOverlay: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    viewModel.forceReload()
                }) {
                    Image(systemSymbol: .arrowClockwise)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .padding(DesignSystem.Spaces.one)
                        .modifier(GlassBackgroundModifier(shape: .circle))
                }
                .padding(DesignSystem.Spaces.one)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var timestampOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                if let snapshotDate = viewModel.snapshotDate {
                    Text(snapshotDate, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, DesignSystem.Spaces.one)
                        .padding(.vertical, DesignSystem.Spaces.half)
                        .modifier(GlassBackgroundModifier(shape: .capsule))
                        .padding(DesignSystem.Spaces.one)
                }
            }
        }
    }
}

// MARK: - Glass Background Modifier

private struct GlassBackgroundModifier: ViewModifier {
    enum BackgroundShape {
        case roundedRectangle
        case circle
        case capsule
    }

    let shape: BackgroundShape
    let cornerRadius: CGFloat?

    init(shape: BackgroundShape = .roundedRectangle, cornerRadius: CGFloat? = nil) {
        self.shape = shape
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            // Use modern Liquid Glass effect
            content
                .glassEffect(in: shapeForGlass)
        } else {
            let color = Color(uiColor: .systemBackground).opacity(0.6)
            // Fallback for older iOS versions
            switch shape {
            case .roundedRectangle:
                content
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius ?? DesignSystem.CornerRadius.one))
            case .circle:
                content
                    .background(color)
                    .clipShape(Circle())
            case .capsule:
                content
                    .background(color)
                    .clipShape(Capsule())
            }
        }
    }

    @available(iOS 26, *)
    private var shapeForGlass: AnyShape {
        switch shape {
        case .roundedRectangle:
            return AnyShape(.rect(cornerRadius: cornerRadius ?? DesignSystem.CornerRadius.one))
        case .circle:
            return AnyShape(.circle)
        case .capsule:
            return AnyShape(.capsule)
        }
    }
}
