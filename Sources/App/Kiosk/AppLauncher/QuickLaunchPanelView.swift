import Combine
import Shared
import SwiftUI

// MARK: - Quick Launch Panel View

/// A slide-out panel showing app shortcuts for quick launching
public struct QuickLaunchPanelView: View {
    @ObservedObject private var manager = AppLauncherManager.shared
    @ObservedObject private var kioskManager = KioskModeManager.shared
    @Binding var isPresented: Bool

    @State private var searchText = ""

    public init(isPresented: Binding<Bool>) {
        _isPresented = isPresented
    }

    private var filteredShortcuts: [AppShortcut] {
        let shortcuts = kioskManager.settings.appShortcuts
        if searchText.isEmpty {
            return shortcuts
        }
        return shortcuts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Search (if many shortcuts)
            if kioskManager.settings.appShortcuts.count > KioskConstants.Panel.searchThreshold {
                searchBar
            }

            // App grid
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(filteredShortcuts) { shortcut in
                        AppShortcutButton(shortcut: shortcut) {
                            launchApp(shortcut)
                        }
                    }
                }
                .padding()
            }

            // Away status (if active)
            if manager.isAway {
                awayStatusView
            }
        }
        .background(Color(.systemBackground).opacity(0.95))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 16)]
    }

    private var headerView: some View {
        HStack {
            Text("Quick Launch")
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel(KioskConstants.Accessibility.closeButton)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search apps...", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var awayStatusView: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.orange)

            if let app = manager.launchedApp {
                Text("In \(app.name)")
                    .font(.caption)
            }

            Spacer()

            if manager.returnTimeRemaining > 0 {
                Text(formatTimeRemaining(manager.returnTimeRemaining))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    }

    private func launchApp(_ shortcut: AppShortcut) {
        isPresented = false

        // Small delay to allow panel to dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            _ = manager.launchShortcut(shortcut)
        }
    }

    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - App Shortcut Button

struct AppShortcutButton: View {
    let shortcut: AppShortcut
    let action: () -> Void

    @State private var canLaunch: Bool = true

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Icon
                iconView
                    .frame(width: KioskConstants.UI.appIconSize, height: KioskConstants.UI.appIconSize)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(KioskConstants.UI.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: KioskConstants.UI.cornerRadius)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )

                // Name
                Text(shortcut.name)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(.primary)
            }
            .opacity(canLaunch ? 1 : 0.5)
        }
        .disabled(!canLaunch)
        .accessibilityLabel(KioskConstants.Accessibility.appShortcut(shortcut.name))
        .accessibilityHint(canLaunch ? "Double tap to launch" : "App not available")
        .onAppear {
            canLaunch = AppLauncherManager.shared.canLaunch(urlScheme: shortcut.urlScheme)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let systemImage = shortcut.systemImage {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(.accentColor)
        } else {
            // Use IconMapper to convert MDI icon to SF Symbol
            Image(systemName: IconMapper.sfSymbol(from: shortcut.icon, default: "app.fill"))
                .font(.title2)
                .foregroundColor(.accentColor)
        }
    }
}

// MARK: - Quick Launch Panel Container

/// Container view that handles gesture-based presentation of the quick launch panel
public struct QuickLaunchContainerView: View {
    @ObservedObject private var kioskManager = KioskModeManager.shared
    @ObservedObject private var panelManager = QuickLaunchPanelManager.shared
    @State private var dragOffset: CGFloat = 0

    private var gesture: QuickLaunchGesture {
        kioskManager.settings.quickLaunchGesture
    }

    private var isPanelPresented: Bool {
        get { panelManager.isPresented }
    }

    private func setPanelPresented(_ value: Bool) {
        panelManager.isPresented = value
    }

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Panel overlay (only when presented)
                if isPanelPresented {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring()) {
                                setPanelPresented(false)
                            }
                        }

                    panelView(in: geometry)
                        .transition(.move(edge: panelEdge).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(), value: isPanelPresented)
        // Only allow hit testing when panel is actually presented
        .allowsHitTesting(isPanelPresented)
    }

    @ViewBuilder
    private func edgeGestureOverlay(in geometry: GeometryProxy) -> some View {
        let edgeSize = KioskConstants.UI.edgeGestureSize

        // Only show edge detectors when panel is not presented
        if !isPanelPresented {
            switch gesture {
            case .swipeFromBottom:
                VStack {
                    Spacer()
                    Color.clear
                        .frame(height: edgeSize)
                        .contentShape(Rectangle())
                        .gesture(edgeGesture(in: geometry))
                }
            case .swipeFromTop:
                VStack {
                    Color.clear
                        .frame(height: edgeSize)
                        .contentShape(Rectangle())
                        .gesture(edgeGesture(in: geometry))
                    Spacer()
                }
            case .swipeFromLeft:
                HStack {
                    Color.clear
                        .frame(width: edgeSize)
                        .contentShape(Rectangle())
                        .gesture(edgeGesture(in: geometry))
                    Spacer()
                }
            case .swipeFromRight:
                HStack {
                    Spacer()
                    Color.clear
                        .frame(width: edgeSize)
                        .contentShape(Rectangle())
                        .gesture(edgeGesture(in: geometry))
                }
            case .doubleTap, .longPress:
                EmptyView()
            }
        }
    }

    private var panelEdge: Edge {
        switch gesture {
        case .swipeFromBottom: return .bottom
        case .swipeFromTop: return .top
        case .swipeFromLeft: return .leading
        case .swipeFromRight: return .trailing
        case .doubleTap, .longPress: return .bottom
        }
    }

    @ViewBuilder
    private func panelView(in geometry: GeometryProxy) -> some View {
        let panelSize = panelSize(in: geometry)

        QuickLaunchPanelView(isPresented: $panelManager.isPresented)
            .frame(width: panelSize.width, height: panelSize.height)
            .position(panelPosition(in: geometry, size: panelSize))
    }

    private func panelSize(in geometry: GeometryProxy) -> CGSize {
        let maxWidth = min(geometry.size.width * KioskConstants.Panel.maxWidthRatio, KioskConstants.Panel.maxWidth)
        let maxHeight = min(geometry.size.height * KioskConstants.Panel.maxHeightRatio, KioskConstants.Panel.maxHeight)
        return CGSize(width: maxWidth, height: maxHeight)
    }

    private func panelPosition(in geometry: GeometryProxy, size: CGSize) -> CGPoint {
        let centerX = geometry.size.width / 2
        let centerY = geometry.size.height / 2

        switch gesture {
        case .swipeFromBottom:
            return CGPoint(x: centerX, y: geometry.size.height - size.height / 2 - 20)
        case .swipeFromTop:
            return CGPoint(x: centerX, y: size.height / 2 + 20)
        case .swipeFromLeft:
            return CGPoint(x: size.width / 2 + 20, y: centerY)
        case .swipeFromRight:
            return CGPoint(x: geometry.size.width - size.width / 2 - 20, y: centerY)
        case .doubleTap, .longPress:
            return CGPoint(x: centerX, y: centerY)
        }
    }

    private func edgeGesture(in geometry: GeometryProxy) -> some Gesture {
        let threshold = KioskConstants.UI.swipeThreshold

        return DragGesture(minimumDistance: 20)
            .onChanged { value in
                switch gesture {
                case .swipeFromBottom, .swipeFromTop:
                    dragOffset = value.translation.height
                case .swipeFromLeft, .swipeFromRight:
                    dragOffset = value.translation.width
                default:
                    break
                }
            }
            .onEnded { value in
                switch gesture {
                case .swipeFromBottom:
                    if value.translation.height < -threshold {
                        setPanelPresented(true)
                    }
                case .swipeFromTop:
                    if value.translation.height > threshold {
                        setPanelPresented(true)
                    }
                case .swipeFromLeft:
                    if value.translation.width > threshold {
                        setPanelPresented(true)
                    }
                case .swipeFromRight:
                    if value.translation.width < -threshold {
                        setPanelPresented(true)
                    }
                default:
                    break
                }

                dragOffset = 0
            }
    }
}

// MARK: - Quick Launch Panel Manager

/// Manages the quick launch panel state and presentation
@MainActor
public final class QuickLaunchPanelManager: ObservableObject {
    public static let shared = QuickLaunchPanelManager()

    @Published public var isPresented: Bool = false

    private init() {}

    public func show() {
        isPresented = true
    }

    public func hide() {
        isPresented = false
    }

    public func toggle() {
        isPresented.toggle()
    }
}

// MARK: - Quick Launch Passthrough View

/// Custom UIView that only intercepts touches when the quick launch panel is visible
public final class QuickLaunchPassthroughView: UIView {
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Only intercept touches when the panel is visible
        guard QuickLaunchPanelManager.shared.isPresented else {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}

/// UIViewController that hosts QuickLaunchContainerView with proper touch passthrough
public final class QuickLaunchViewController: UIViewController {
    private var hostingController: UIHostingController<QuickLaunchContainerView>?

    public override func loadView() {
        view = QuickLaunchPassthroughView()
        view.backgroundColor = .clear
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        let containerView = QuickLaunchContainerView()
        let hosting = UIHostingController(rootView: containerView)
        hosting.view.backgroundColor = .clear

        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        hosting.didMove(toParent: self)
        hostingController = hosting
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    QuickLaunchPanelView(isPresented: .constant(true))
        .frame(width: 350, height: 400)
        .padding()
        .background(Color.gray)
}
