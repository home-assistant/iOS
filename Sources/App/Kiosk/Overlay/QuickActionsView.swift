import Combine
import HAKit
import Shared
import SwiftUI

// MARK: - Quick Actions View

/// A slide-out panel showing configurable quick actions for HA control
public struct QuickActionsView: View {
    @ObservedObject private var kioskManager = KioskModeManager.shared
    @Binding var isPresented: Bool

    @State private var executingActionId: String?
    @State private var feedbackMessage: String?

    public init(isPresented: Binding<Bool>) {
        _isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Actions grid
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: KioskConstants.UI.standardPadding) {
                    ForEach(kioskManager.settings.quickActions) { action in
                        QuickActionButton(
                            action: action,
                            isExecuting: executingActionId == action.id
                        ) {
                            executeAction(action)
                        }
                    }
                }
                .padding()
            }

            // Feedback message
            if let message = feedbackMessage {
                feedbackView(message: message)
            }
        }
        .background(Color(.systemBackground).opacity(0.95))
        .cornerRadius(KioskConstants.UI.cornerRadius)
        .shadow(color: .black.opacity(KioskConstants.Shadow.panelOpacity),
                radius: KioskConstants.Shadow.panelRadius, x: 0, y: 5)
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 90, maximum: 110), spacing: KioskConstants.UI.standardPadding)]
    }

    private var headerView: some View {
        HStack {
            Text("Quick Actions")
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

    private func feedbackView(message: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(message)
                .font(.caption)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Action Execution

    private func executeAction(_ action: QuickAction) {
        executingActionId = action.id
        TouchFeedbackManager.shared.playFeedback(for: .action)

        Task {
            let success = await QuickActionsManager.shared.executeAction(action)

            await MainActor.run {
                executingActionId = nil

                if success {
                    showFeedback("Done")
                } else {
                    showFeedback("Failed")
                }
            }
        }
    }

    private func showFeedback(_ message: String) {
        withAnimation {
            feedbackMessage = message
        }

        Task {
            try? await Task.sleep(nanoseconds: UInt64(KioskConstants.Timing.feedbackDuration * 1_000_000_000))
            await MainActor.run {
                withAnimation {
                    feedbackMessage = nil
                }
            }
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let action: QuickAction
    let isExecuting: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    // Icon
                    Image(systemName: IconMapper.sfSymbol(from: action.icon, default: "star.fill"))
                        .font(.title2)
                        .foregroundColor(.accentColor)
                        .opacity(isExecuting ? 0.3 : 1)

                    // Loading indicator
                    if isExecuting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
                .frame(width: KioskConstants.UI.appIconSize, height: KioskConstants.UI.appIconSize)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(KioskConstants.UI.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: KioskConstants.UI.cornerRadius)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )

                // Name
                Text(action.name)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
            }
        }
        .disabled(isExecuting)
        .accessibilityLabel(action.name)
        .accessibilityHint("Double tap to execute")
    }
}

// MARK: - Quick Actions Container

/// Container view that handles gesture-based presentation of the quick actions panel
public struct QuickActionsContainerView: View {
    @ObservedObject private var kioskManager = KioskModeManager.shared
    @State private var isPanelPresented = false
    @State private var dragOffset: CGFloat = 0

    private var gesture: QuickLaunchGesture {
        kioskManager.settings.quickActionsGesture
    }

    private var isEnabled: Bool {
        kioskManager.isKioskModeActive && kioskManager.settings.quickActionsEnabled
    }

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Invisible gesture detector
                if isEnabled {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(edgeGesture(in: geometry))
                }

                // Panel overlay
                if isPanelPresented {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring()) {
                                isPanelPresented = false
                            }
                        }

                    panelView(in: geometry)
                        .transition(.move(edge: panelEdge).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(), value: isPanelPresented)
    }

    private var panelEdge: Edge {
        switch gesture {
        case .swipeFromBottom: return .bottom
        case .swipeFromTop: return .top
        case .swipeFromLeft: return .leading
        case .swipeFromRight: return .trailing
        case .doubleTap, .longPress: return .trailing
        }
    }

    @ViewBuilder
    private func panelView(in geometry: GeometryProxy) -> some View {
        let panelSize = panelSize(in: geometry)

        QuickActionsView(isPresented: $isPanelPresented)
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
        let padding: CGFloat = 20

        switch gesture {
        case .swipeFromBottom:
            return CGPoint(x: centerX, y: geometry.size.height - size.height / 2 - padding)
        case .swipeFromTop:
            return CGPoint(x: centerX, y: size.height / 2 + padding)
        case .swipeFromLeft:
            return CGPoint(x: size.width / 2 + padding, y: centerY)
        case .swipeFromRight:
            return CGPoint(x: geometry.size.width - size.width / 2 - padding, y: centerY)
        case .doubleTap, .longPress:
            return CGPoint(x: centerX, y: centerY)
        }
    }

    private func edgeGesture(in geometry: GeometryProxy) -> some Gesture {
        let edgeSize = KioskConstants.UI.edgeGestureSize
        let threshold = KioskConstants.UI.swipeThreshold

        return DragGesture(minimumDistance: 20)
            .onChanged { value in
                let startLocation = value.startLocation

                switch gesture {
                case .swipeFromBottom:
                    if startLocation.y > geometry.size.height - edgeSize {
                        dragOffset = value.translation.height
                    }
                case .swipeFromTop:
                    if startLocation.y < edgeSize {
                        dragOffset = value.translation.height
                    }
                case .swipeFromLeft:
                    if startLocation.x < edgeSize {
                        dragOffset = value.translation.width
                    }
                case .swipeFromRight:
                    if startLocation.x > geometry.size.width - edgeSize {
                        dragOffset = value.translation.width
                    }
                default:
                    break
                }
            }
            .onEnded { value in
                switch gesture {
                case .swipeFromBottom:
                    if value.startLocation.y > geometry.size.height - edgeSize,
                       value.translation.height < -threshold {
                        isPanelPresented = true
                    }
                case .swipeFromTop:
                    if value.startLocation.y < edgeSize,
                       value.translation.height > threshold {
                        isPanelPresented = true
                    }
                case .swipeFromLeft:
                    if value.startLocation.x < edgeSize,
                       value.translation.width > threshold {
                        isPanelPresented = true
                    }
                case .swipeFromRight:
                    if value.startLocation.x > geometry.size.width - edgeSize,
                       value.translation.width < -threshold {
                        isPanelPresented = true
                    }
                default:
                    break
                }

                dragOffset = 0
            }
    }
}

// MARK: - Quick Actions Manager

/// Manages execution of quick actions
@MainActor
public final class QuickActionsManager: ObservableObject {
    public static let shared = QuickActionsManager()

    private init() {}

    /// Execute a quick action
    public func executeAction(_ action: QuickAction) async -> Bool {
        Current.Log.info("Executing quick action: \(action.name)")

        switch action.actionType {
        case let .haService(domain, service, data):
            return await callHAService(domain: domain, service: service, data: data)

        case let .navigate(url):
            KioskModeManager.shared.navigate(to: url)
            return true

        case let .toggleEntity(entityId):
            return await toggleEntity(entityId)

        case let .script(entityId):
            return await callHAService(domain: "script", service: "turn_on", data: ["entity_id": entityId])

        case let .scene(entityId):
            return await callHAService(domain: "scene", service: "turn_on", data: ["entity_id": entityId])
        }
    }

    private func callHAService(domain: String, service: String, data: [String: String]) async -> Bool {
        guard let server = Current.servers.all.first,
              let api = Current.api(for: server) else {
            Current.Log.error("No HA server available for service call")
            return false
        }

        do {
            let serviceData: [String: Any] = data
            _ = try await api.connection.send(.callService(
                domain: .init(stringLiteral: domain),
                service: .init(stringLiteral: service),
                data: serviceData
            )).promise.value

            Current.Log.info("Service call successful: \(domain).\(service)")
            return true
        } catch {
            Current.Log.error("Service call failed: \(error.localizedDescription)")
            return false
        }
    }

    private func toggleEntity(_ entityId: String) async -> Bool {
        // Determine domain from entity_id
        let domain = entityId.components(separatedBy: ".").first ?? "homeassistant"

        // Use appropriate toggle service based on domain
        let toggleDomain: String
        let toggleService: String

        switch domain {
        case "light", "switch", "fan", "input_boolean", "automation", "script":
            toggleDomain = domain
            toggleService = "toggle"
        case "cover":
            toggleDomain = "cover"
            toggleService = "toggle"
        case "lock":
            // Locks don't have toggle - need to check state first
            toggleDomain = "lock"
            toggleService = "toggle"
        case "media_player":
            toggleDomain = "media_player"
            toggleService = "toggle"
        default:
            toggleDomain = "homeassistant"
            toggleService = "toggle"
        }

        return await callHAService(
            domain: toggleDomain,
            service: toggleService,
            data: ["entity_id": entityId]
        )
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    QuickActionsView(isPresented: .constant(true))
        .frame(width: 350, height: 400)
        .padding()
        .background(Color.gray)
}
