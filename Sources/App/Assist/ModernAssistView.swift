import Combine
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct ModernAssistView: View, KeyboardReadable {
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Constants

    private enum Constants {
        // Layout
        static let inputHeight: CGFloat = 50
        static let textFieldHeight: CGFloat = 50
        static let buttonWidth: CGFloat = 60
        static let orbSize: CGFloat = 300
        static let orbRadius: CGFloat = 150

        // Spacing
        static let horizontalPadding: CGFloat = DesignSystem.Spaces.two
        static let headerHorizontalPadding: CGFloat = DesignSystem.Spaces.three
        static let verticalPadding: CGFloat = DesignSystem.Spaces.oneAndHalf
        static let messageSpacing: CGFloat = DesignSystem.Spaces.two
        static let headerTopPadding: CGFloat = 60
        static let headerBottomPadding: CGFloat = DesignSystem.Spaces.two
        static let inputVerticalPadding: CGFloat = DesignSystem.Spaces.two
        static let messageBubbleHorizontalPadding: CGFloat = DesignSystem.Spaces.two
        static let messageBubbleVerticalPadding: CGFloat = DesignSystem.Spaces.oneAndHalf
        static let minSpacerLength: CGFloat = DesignSystem.Spaces.five
        static let bottomScrollInset: CGFloat = 60

        // Corner Radius
        static let messageBubbleCornerRadius: CGFloat = DesignSystem.CornerRadius.two

        // Blur
        static let backgroundBlurRadius: CGFloat = DesignSystem.Spaces.five
        static let materialBlurRadius: CGFloat = DesignSystem.Spaces.two

        // Offsets
        static let topMaterialOffset: CGFloat = 0
        static let bottomMaterialOffset: CGFloat = DesignSystem.Spaces.two
        static let orbYOffsetMin: CGFloat = -50
        static let orbYOffsetMax: CGFloat = 50
        static let orbYOffset2Min: CGFloat = 0
        static let orbYOffset2Max: CGFloat = 100
        static let orbXOffsetLeft: CGFloat = -100
        static let pickerXOffset: CGFloat = -5

        // Opacity
        static let topMaterialOpacity: Double = 0.5
        static let bottomMaterialOpacity: Double = 0.9
        static let orbOpacity: Double = 0.3
        static let whiteTextOpacity: Double = 0.95
        static let buttonTextOpacity: Double = 0.7
        static let assistantBubbleOpacity: Double = 0.1
        static let strokeStartOpacity: Double = 0.3
        static let strokeEndOpacity: Double = 0.1
        static let userBubbleOpacity: Double = 0.8
        static let headerGradientOpacity: Double = 0.8

        // Stroke Width
        static let messageBubbleStrokeWidth: CGFloat = DesignSystem.Border.Width.default

        // Font Sizes
        static let titleFontSize: CGFloat = 34

        // Animation Durations
        static let ambientAnimationDuration: Double = 4
        static let recordingAnimationDuration: Double = 1.5
        static let sendSpringResponse: Double = 0.3
        static let recordingSpringResponse: Double = 0.4
        static let recordingSpringDamping: Double = 0.7

        // Identifiers
        static let bottomScrollAnchor: String = "bottom"
    }

    @Binding var isRecording: Bool
    @Binding var inputText: String
    @State private var pulseAnimation = false
    @State private var glowIntensity: CGFloat = 0
    @Binding var selectedTheme: ModernAssistTheme
    @Binding var selectedPipeline: String
    @FocusState private var isTextFieldFocused: Bool
    @State private var keyboardObserver: AnyCancellable?
    @State private var keyboardVisible = false

    @Binding var messages: [AssistChatItem]
    var pipelines: [String]

    let onClose: () -> Void
    let onSettings: () -> Void
    let onSendMessage: () -> Void
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void

    init(
        messages: Binding<[AssistChatItem]>,
        inputText: Binding<String>,
        isRecording: Binding<Bool>,
        selectedTheme: Binding<ModernAssistTheme>,
        selectedPipeline: Binding<String>,
        pipelines: [String],
        onClose: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        onSendMessage: @escaping () -> Void,
        onStartRecording: @escaping () -> Void,
        onStopRecording: @escaping () -> Void
    ) {
        self._messages = messages
        self._inputText = inputText
        self._isRecording = isRecording
        self._selectedTheme = selectedTheme
        self._selectedPipeline = selectedPipeline
        self.pipelines = pipelines
        self.onClose = onClose
        self.onSettings = onSettings
        self.onSendMessage = onSendMessage
        self.onStartRecording = onStartRecording
        self.onStopRecording = onStopRecording
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()
                chatArea
            }
            .toolbar(content: {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onSettings) {
                        Image(systemSymbol: .gearshapeFill)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton {
                        onClose()
                    }
                }
            })
            .safeAreaInset(edge: .top, content: {
                modernHeader
                    .ignoresSafeArea()
            })
            .safeAreaInset(edge: .bottom, content: {
                modernInputArea
            })
            .scrollEdgeEffectStyle(.soft, for: .all)
            .onAppear {
                startAmbientAnimation()
            }
            .onReceive(keyboardPublisher) { newIsKeyboardVisible in
                keyboardVisible = newIsKeyboardVisible
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: selectedTheme.gradientColors(for: colorScheme),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay {
            // Animated orbs in background
            GeometryReader { geometry in
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    selectedTheme.orbColors(for: colorScheme).0.opacity(selectedTheme.orbOpacity(
                                        for: colorScheme,
                                        defaultOpacity: Constants.orbOpacity
                                    )),
                                    Color.clear,
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: Constants.orbRadius
                            )
                        )
                        .frame(width: Constants.orbSize, height: Constants.orbSize)
                        .offset(
                            x: Constants.orbXOffsetLeft,
                            y: pulseAnimation ? Constants.orbYOffsetMin : Constants.orbYOffsetMax
                        )
                        .blur(radius: Constants.backgroundBlurRadius)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    selectedTheme.orbColors(for: colorScheme).1.opacity(selectedTheme.orbOpacity(
                                        for: colorScheme,
                                        defaultOpacity: Constants.orbOpacity
                                    )),
                                    Color.clear,
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: Constants.orbRadius
                            )
                        )
                        .frame(width: Constants.orbSize, height: Constants.orbSize)
                        .offset(
                            x: geometry.size.width - Constants.orbXOffsetLeft * -1,
                            y: pulseAnimation ? Constants.orbYOffset2Max : Constants.orbYOffset2Min
                        )
                        .blur(radius: Constants.backgroundBlurRadius)
                }
            }
        }
    }

    // MARK: - Header

    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Assist.ModernUi.Header.title)
                    .font(.system(size: Constants.titleFontSize, weight: .bold))
                    .foregroundStyle(selectedTheme.headerTextColor(for: colorScheme))
                Picker(L10n.Assist.ModernUi.Pipeline.label, selection: $selectedPipeline) {
                    ForEach(pipelines, id: \.self) { pipeline in
                        Text(pipeline)
                            .tag(pipeline)
                    }
                }
                .pickerStyle(.menu)
                .buttonStyle(.glass)
                .offset(x: Constants.pickerXOffset)
            }

            Spacer()
        }
        .padding(.horizontal, Constants.headerHorizontalPadding)
        .padding(.top, Constants.headerTopPadding)
        .padding(.bottom, Constants.headerBottomPadding)
        .background(topGradientView)
    }

    // MARK: - Chat Area

    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: Constants.messageSpacing) {
                    ForEach(messages) { message in
                        modernMessageBubble(message: message)
                            .id(message.id)
                    }
                    VStack {}
                        .frame(height: Constants.bottomScrollInset)
                        .id(Constants.bottomScrollAnchor)
                }
                .padding(.horizontal, Constants.horizontalPadding)
                .padding(.vertical, Constants.verticalPadding)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(Constants.bottomScrollAnchor, anchor: .bottom)
                }
            }
            .onChange(of: keyboardVisible, { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(Constants.bottomScrollAnchor, anchor: .bottom)
                }
            })
            .onAppear {
                proxy.scrollTo(Constants.bottomScrollAnchor, anchor: .bottom)
            }
        }
    }

    private func modernMessageBubble(message: AssistChatItem) -> some View {
        let isUser = message.itemType == .input
        let isTyping = message.itemType == .typing
        let alignment: HorizontalAlignment = {
            switch message.itemType {
            case .input:
                .trailing
            case .output:
                .leading
            case .typing:
                .leading
            case .error:
                .center
            case .info:
                .center
            }
        }()
        let alignment2: Alignment = {
            switch message.itemType {
            case .input:
                .trailing
            case .output:
                .leading
            case .typing:
                .leading
            case .error:
                .center
            case .info:
                .center
            }
        }()

        return HStack {
            VStack(alignment: alignment, spacing: .zero) {
                Group {
                    if isTyping {
                        AssistTypingIndicator()
                            .padding(.vertical, DesignSystem.Spaces.half)
                    } else {
                        Text(message.content)
                            .font(.body)
                            .foregroundColor(isUser ? .white : selectedTheme.secondaryTextColor(for: colorScheme))
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal, Constants.messageBubbleHorizontalPadding)
                .padding(.vertical, Constants.messageBubbleVerticalPadding)
                .glassEffect(
                    isUser ? .regular.tint(.haPrimary).interactive() : .clear.interactive(),
                    in: RoundedRectangle(cornerRadius: Constants.messageBubbleCornerRadius, style: .continuous)
                )
            }
            .frame(maxWidth: .infinity, alignment: alignment2)
        }
    }

    private var messageBackgroundColor: Color {
        if selectedTheme == .homeAssistant {
            return colorScheme == .dark ? .white.opacity(Constants.assistantBubbleOpacity) : .black.opacity(0.05)
        }
        return .white.opacity(Constants.assistantBubbleOpacity)
    }

    private var messageStrokeColor: Color {
        if selectedTheme == .homeAssistant {
            return colorScheme == .dark ? .white : .black
        }
        return .white
    }

    // MARK: - Input Area

    private var modernInputArea: some View {
        ZStack {
            bottomGradientView
                .ignoresSafeArea()
            Group {
                // Recording state - animated orb
                if isRecording {
                    recordingOrb
                        .transition(.scale.combined(with: .opacity))
                } else {
                    inputControls
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.bottom, keyboardVisible ? DesignSystem.Spaces.two : .zero)
        }
        .frame(height: Constants.inputHeight)
        .frame(maxWidth: .infinity)
    }

    private var bottomGradientView: some View {
        let gradientColor: Color = {
            if selectedTheme == .homeAssistant {
                return colorScheme == .dark ? .black : .white
            }
            return .black
        }()

        return LinearGradient(colors: [gradientColor, .clear], startPoint: .bottom, endPoint: .top)
    }

    private var topGradientView: some View {
        let gradientColor: Color = {
            if selectedTheme == .homeAssistant {
                return colorScheme == .dark ? .black : .white
            }
            return .black
        }()

        return LinearGradient(colors: [gradientColor, .clear], startPoint: .top, endPoint: .bottom)
    }

    private var recordingOrb: some View {
        AssistWavesAnimation()
            .frame(height: Constants.inputHeight)
            .frame(maxWidth: .infinity)
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    onStopRecording()
                }
            }
            .sensoryFeedback(.warning, trigger: isRecording)
            .sensoryFeedback(.success, trigger: !isRecording)
    }

    private var inputControls: some View {
        GlassEffectContainer {
            HStack(spacing: DesignSystem.Spaces.one) {
                // Text input field
                TextField(L10n.Assist.ModernUi.TextField.placeholder, text: $inputText)
                    .focused($isTextFieldFocused)
                    .foregroundColor(selectedTheme.textFieldTextColor(for: colorScheme))
                    .tint(.blue)
                    .padding(.leading, Constants.horizontalPadding)
                    .frame(height: Constants.textFieldHeight)
                    .glassEffect(.clear.interactive(), in: .capsule)
                    .padding(.leading, Constants.horizontalPadding)
                    .onSubmit {
                        onSendMessage()
                    }

                Button(action: {
                    withAnimation(.spring(
                        response: Constants.recordingSpringResponse,
                        dampingFraction: Constants.recordingSpringDamping
                    )) {
                        if inputText.isEmpty {
                            onStartRecording()
                        } else {
                            onSendMessage()
                        }
                    }
                }) {
                    Image(systemSymbol: inputText.isEmpty ? .micFill : .arrowUp)
                        .contentTransition(.symbolEffect(
                            .replace.magic(fallback: .downUp.byLayer),
                            options: .repeat(.continuous)
                        ))
                        .font(.title3)
                        .foregroundColor(selectedTheme.buttonTextColor(for: colorScheme))
                        .padding()
                        .glassEffect(.clear.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .padding(.trailing, Constants.horizontalPadding)
            }
        }
    }

    // MARK: - Animations

    private func startAmbientAnimation() {
        withAnimation(.easeInOut(duration: Constants.ambientAnimationDuration).repeatForever(autoreverses: true)) {
            pulseAnimation = true
        }

        // Start recording animation when recording
        withAnimation(.easeInOut(duration: Constants.recordingAnimationDuration).repeatForever(autoreverses: true)) {
            if isRecording {
                glowIntensity = 1
            }
        }
    }
}

// MARK: - Background Theme

enum ModernAssistTheme: String, CaseIterable, Identifiable {
    case homeAssistant = "Home Assistant"
    case midnight = "Midnight"
    case aurora = "Aurora"
    case sunset = "Sunset"
    case ocean = "Ocean"
    case forest = "Forest"
    case galaxy = "Galaxy"
    case lavender = "Lavender"
    case ember = "Ember"

    var id: String { rawValue }

    func gradientColors(for colorScheme: ColorScheme) -> [Color] {
        switch self {
        case .midnight:
            return [
                Color(red: 0.05, green: 0.05, blue: 0.15),
                Color(red: 0.1, green: 0.05, blue: 0.2),
                Color(red: 0.05, green: 0.1, blue: 0.25),
            ]
        case .aurora:
            return [
                Color(red: 0.0, green: 0.15, blue: 0.2),
                Color(red: 0.1, green: 0.2, blue: 0.3),
                Color(red: 0.0, green: 0.25, blue: 0.25),
            ]
        case .sunset:
            return [
                Color(red: 0.2, green: 0.05, blue: 0.15),
                Color(red: 0.25, green: 0.1, blue: 0.15),
                Color(red: 0.15, green: 0.05, blue: 0.2),
            ]
        case .ocean:
            return [
                Color(red: 0.0, green: 0.1, blue: 0.2),
                Color(red: 0.0, green: 0.15, blue: 0.25),
                Color(red: 0.05, green: 0.2, blue: 0.3),
            ]
        case .forest:
            return [
                Color(red: 0.05, green: 0.15, blue: 0.1),
                Color(red: 0.1, green: 0.2, blue: 0.15),
                Color(red: 0.05, green: 0.15, blue: 0.2),
            ]
        case .galaxy:
            return [
                Color(red: 0.1, green: 0.05, blue: 0.2),
                Color(red: 0.15, green: 0.05, blue: 0.25),
                Color(red: 0.2, green: 0.1, blue: 0.3),
            ]
        case .lavender:
            return [
                Color(red: 0.15, green: 0.1, blue: 0.2),
                Color(red: 0.18, green: 0.12, blue: 0.25),
                Color(red: 0.2, green: 0.15, blue: 0.3),
            ]
        case .ember:
            return [
                Color(red: 0.2, green: 0.08, blue: 0.05),
                Color(red: 0.25, green: 0.1, blue: 0.08),
                Color(red: 0.2, green: 0.12, blue: 0.1),
            ]
        case .homeAssistant:
            if colorScheme == .dark {
                return [
                    Color(red: 0.02, green: 0.02, blue: 0.08), // Very dark with blue tint
                    Color(red: 0.05, green: 0.08, blue: 0.15), // Dark with more blue
                    Color(red: 0.08, green: 0.12, blue: 0.2), // Medium-dark with prominent blue
                ]
            } else {
                return [
                    Color(red: 0.88, green: 0.92, blue: 0.98), // Very light with blue tint
                    Color(red: 0.9, green: 0.93, blue: 0.96), // Light with subtle blue
                    Color(red: 0.92, green: 0.94, blue: 0.97), // Almost white with blue hint
                ]
            }
        }
    }

    var gradientColors: [Color] {
        gradientColors(for: .dark)
    }

    func orbColors(for colorScheme: ColorScheme) -> (Color, Color) {
        switch self {
        case .midnight:
            return (.blue, .purple)
        case .aurora:
            return (.cyan, .teal)
        case .sunset:
            return (.orange, .pink)
        case .ocean:
            return (.blue, .cyan)
        case .forest:
            return (.green, .mint)
        case .galaxy:
            return (.purple, .indigo)
        case .lavender:
            return (.purple, .pink)
        case .ember:
            return (.orange, .red)
        case .homeAssistant:
            return (.haPrimary, .haPrimary.opacity(0.7))
        }
    }

    var orbColors: (Color, Color) {
        orbColors(for: .dark)
    }

    // Orb opacity for Home Assistant theme needs to be higher
    func orbOpacity(for colorScheme: ColorScheme, defaultOpacity: Double) -> Double {
        switch self {
        case .homeAssistant:
            return colorScheme == .dark ? 0.5 : 0.4 // Higher opacity for more prominence
        default:
            return defaultOpacity
        }
    }

    // Text colors for different elements
    func primaryTextColor(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .homeAssistant:
            return colorScheme == .dark ? .white : .black
        default:
            return .white
        }
    }

    func secondaryTextColor(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .homeAssistant:
            return colorScheme == .dark ? .white.opacity(0.95) : .black.opacity(0.85)
        default:
            return .white.opacity(0.95)
        }
    }

    func buttonTextColor(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .homeAssistant:
            return colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
        default:
            return .white.opacity(0.7)
        }
    }

    func headerTextColor(for colorScheme: ColorScheme) -> LinearGradient {
        switch self {
        case .homeAssistant:
            if colorScheme == .dark {
                return LinearGradient(
                    colors: [.white, .white.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else {
                return LinearGradient(
                    colors: [.black, .black.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        default:
            return LinearGradient(
                colors: [.white, .white.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    func textFieldTextColor(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .homeAssistant:
            return colorScheme == .dark ? .white : .black
        default:
            return .white
        }
    }
}

@available(iOS 26.0, *)
#Preview("Home Assistant Theme - Light") {
    @Previewable @State var messages: [AssistChatItem] = [
        AssistChatItem(content: "Hello! How can I help you today?", itemType: .output),
        AssistChatItem(content: "What's the weather like?", itemType: .input),
        AssistChatItem(
            content: "I'll check the weather for you. The current temperature is 72°F with clear skies.",
            itemType: .output
        ),
        AssistChatItem(content: "Can you turn on the living room lights?", itemType: .input),
        AssistChatItem(content: "Sure! I've turned on the living room lights for you.", itemType: .output),
    ]
    @Previewable @State var inputText: String = ""
    @Previewable @State var isRecording: Bool = false
    @Previewable @State var selectedTheme: ModernAssistTheme = .homeAssistant
    @Previewable @State var selectedPipeline: String = "Home Assistant"

    let pipelines = ["Home Assistant", "OpenAI", "Local Model"]

    return ModernAssistView(
        messages: $messages,
        inputText: $inputText,
        isRecording: $isRecording,
        selectedTheme: $selectedTheme,
        selectedPipeline: $selectedPipeline,
        pipelines: pipelines,
        onClose: {
            print("Close tapped")
        },
        onSettings: {
            print("Settings tapped")
        },
        onSendMessage: {
            print("Send message tapped")
        },
        onStartRecording: {
            print("Start recording tapped")
            isRecording = true
        },
        onStopRecording: {
            print("Stop recording tapped")
            isRecording = false
        }
    )
    .environment(\.colorScheme, .light)
}

@available(iOS 26.0, *)
#Preview("Home Assistant Theme - Dark") {
    @Previewable @State var messages: [AssistChatItem] = [
        AssistChatItem(content: "Hello! How can I help you today?", itemType: .output),
        AssistChatItem(content: "What's the weather like?", itemType: .input),
        AssistChatItem(
            content: "I'll check the weather for you. The current temperature is 72°F with clear skies.",
            itemType: .output
        ),
        AssistChatItem(content: "Can you turn on the living room lights?", itemType: .input),
        AssistChatItem(content: "Sure! I've turned on the living room lights for you.", itemType: .output),
    ]
    @Previewable @State var inputText: String = ""
    @Previewable @State var isRecording: Bool = false
    @Previewable @State var selectedTheme: ModernAssistTheme = .homeAssistant
    @Previewable @State var selectedPipeline: String = "Home Assistant"

    let pipelines = ["Home Assistant", "OpenAI", "Local Model"]

    return ModernAssistView(
        messages: $messages,
        inputText: $inputText,
        isRecording: $isRecording,
        selectedTheme: $selectedTheme,
        selectedPipeline: $selectedPipeline,
        pipelines: pipelines,
        onClose: {
            print("Close tapped")
        },
        onSettings: {
            print("Settings tapped")
        },
        onSendMessage: {
            print("Send message tapped")
        },
        onStartRecording: {
            print("Start recording tapped")
            isRecording = true
        },
        onStopRecording: {
            print("Stop recording tapped")
            isRecording = false
        }
    )
    .environment(\.colorScheme, .dark)
}
