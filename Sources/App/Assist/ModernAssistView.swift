import SwiftUI
import Shared

@available(iOS 26.0, *)
struct ModernAssistView: View {
    // MARK: - Constants
    private enum Constants {
        // Layout
        static let inputHeight: CGFloat = 120
        static let textFieldHeight: CGFloat = 50
        static let buttonWidth: CGFloat = 60
        static let orbSize: CGFloat = 300
        static let orbRadius: CGFloat = 150
        
        // Spacing
        static let horizontalPadding: CGFloat = 20
        static let headerHorizontalPadding: CGFloat = 24
        static let verticalPadding: CGFloat = 12
        static let messageSpacing: CGFloat = 16
        static let headerTopPadding: CGFloat = 60
        static let headerBottomPadding: CGFloat = 20
        static let inputVerticalPadding: CGFloat = 20
        static let messageBubbleHorizontalPadding: CGFloat = 16
        static let messageBubbleVerticalPadding: CGFloat = 12
        static let minSpacerLength: CGFloat = 40
        static let bottomScrollInset: CGFloat = 120
        
        // Corner Radius
        static let messageBubbleCornerRadius: CGFloat = 20
        
        // Blur
        static let backgroundBlurRadius: CGFloat = 40
        static let materialBlurRadius: CGFloat = 20
        
        // Offsets
        static let topMaterialOffset: CGFloat = 0
        static let bottomMaterialOffset: CGFloat = 20
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
        static let messageBubbleStrokeWidth: CGFloat = 1
        
        // Font Sizes
        static let titleFontSize: CGFloat = 34
        
        // Animation Durations
        static let ambientAnimationDuration: Double = 4
        static let recordingAnimationDuration: Double = 1.5
        static let sendSpringResponse: Double = 0.3
        static let recordingSpringResponse: Double = 0.4
        static let recordingSpringDamping: Double = 0.7
    }
    
    @State private var isRecording = false
    @State private var inputText = ""
    @State private var pulseAnimation = false
    @State private var glowIntensity: CGFloat = 0
    @State private var selectedTheme: ModernAssistTheme
    @FocusState private var isTextFieldFocused: Bool
    
    // Sample chat messages for preview
    @State private var messages: [MockMessage] = [
        MockMessage(text: "Hello! How can I help you today?", isUser: false),
        MockMessage(text: "What's the weather like?", isUser: true),
        MockMessage(text: "I'll check the weather for you. The current temperature is 72°F with clear skies.", isUser: false),
        MockMessage(text: "Can you turn on the living room lights?", isUser: true),
        MockMessage(text: "Sure! I've turned on the living room lights for you.", isUser: false),
        MockMessage(text: "What about the temperature? It feels a bit cold.", isUser: true),
        MockMessage(text: "The thermostat is currently set to 68°F. Would you like me to increase it?", isUser: false),
        MockMessage(text: "Yes, please set it to 72°F", isUser: true),
        MockMessage(text: "Done! I've set the thermostat to 72°F. It should warm up in a few minutes.", isUser: false),
        MockMessage(text: "Thanks! Can you also check if the front door is locked?", isUser: true),
        MockMessage(text: "The front door is currently locked and secure. All entry points are secured.", isUser: false),
        MockMessage(text: "Perfect! What's on my calendar for today?", isUser: true),
        MockMessage(text: "You have 3 events today:\n• 10:00 AM - Team Meeting\n• 2:00 PM - Client Call\n• 5:30 PM - Dentist Appointment", isUser: false),
        MockMessage(text: "Great, thanks for the update!", isUser: true),
        MockMessage(text: "You're welcome! Is there anything else I can help you with?", isUser: false)
    ]
    
    init(selectedTheme: ModernAssistTheme = .ocean) {
        self._selectedTheme = State(initialValue: selectedTheme)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                chatArea
                modernInputArea
            }
            .toolbar(content: {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {}) {
                        Image(systemSymbol: .gearshapeFill)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton {

                    }
                }
            })
            .safeAreaInset(edge: .top, content: {
                modernHeader
            })
            .background(backgroundGradient)
            .ignoresSafeArea(edges: [.bottom, .top])
            .scrollEdgeEffectStyle(.soft, for: .all)
            .onAppear {
                startAmbientAnimation()
            }
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: selectedTheme.gradientColors,
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
                                    selectedTheme.orbColors.0.opacity(Constants.orbOpacity),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: Constants.orbRadius
                            )
                        )
                        .frame(width: Constants.orbSize, height: Constants.orbSize)
                        .offset(x: Constants.orbXOffsetLeft, y: pulseAnimation ? Constants.orbYOffsetMin : Constants.orbYOffsetMax)
                        .blur(radius: Constants.backgroundBlurRadius)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    selectedTheme.orbColors.1.opacity(Constants.orbOpacity),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: Constants.orbRadius
                            )
                        )
                        .frame(width: Constants.orbSize, height: Constants.orbSize)
                        .offset(x: geometry.size.width - Constants.orbXOffsetLeft * -1, y: pulseAnimation ? Constants.orbYOffset2Max : Constants.orbYOffset2Min)
                        .blur(radius: Constants.backgroundBlurRadius)
                }
            }
        }
    }
    
    // MARK: - Header
    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Assist")
                    .font(.system(size: Constants.titleFontSize, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(Constants.headerGradientOpacity)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Picker("Theme", selection: $selectedTheme) {
                    ForEach(ModernAssistTheme.allCases) { theme in
                        Text(theme.rawValue)
                            .tag(theme)
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
                }
                .padding(.horizontal, Constants.horizontalPadding)
                .padding(.vertical, Constants.verticalPadding)
                .padding(.bottom, Constants.bottomScrollInset)
            }
            .onChange(of: messages.count) { oldValue, newValue in
                if let lastMessage = messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let lastMessage = messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
    
    private func modernMessageBubble(message: MockMessage) -> some View {
        HStack {
            if message.isUser { Spacer(minLength: Constants.minSpacerLength) }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 0) {
                Text(message.text)
                    .font(.body)
                    .foregroundColor(message.isUser ? .white : .white.opacity(Constants.whiteTextOpacity))
                    .padding(.horizontal, Constants.messageBubbleHorizontalPadding)
                    .padding(.vertical, Constants.messageBubbleVerticalPadding)
                    .background(
                        ZStack {
                            if message.isUser {
                                RoundedRectangle(cornerRadius: Constants.messageBubbleCornerRadius, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.blue,
                                                Color.blue.opacity(Constants.userBubbleOpacity)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: Constants.messageBubbleCornerRadius, style: .continuous)
                                    .fill(.white.opacity(Constants.assistantBubbleOpacity))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Constants.messageBubbleCornerRadius, style: .continuous)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        .white.opacity(Constants.strokeStartOpacity),
                                                        .white.opacity(Constants.strokeEndOpacity)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: Constants.messageBubbleStrokeWidth
                                            )
                                    )
                            }
                        }
                    )
            }
            
            if !message.isUser { Spacer(minLength: Constants.minSpacerLength) }
        }
    }
    
    // MARK: - Input Area
    private var modernInputArea: some View {
        ZStack {
            // Recording state - animated orb
            if isRecording {
                recordingOrb
                    .transition(.scale.combined(with: .opacity))
            } else {
                inputControls
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: Constants.inputHeight)
        .frame(maxWidth: .infinity)
        .ignoresSafeArea()
        .background(
            bottomGradientView
        )
    }

    private var bottomGradientView: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .blur(radius: Constants.materialBlurRadius)
            .offset(y: Constants.bottomMaterialOffset)
            .preferredColorScheme(.dark)
            .opacity(Constants.bottomMaterialOpacity)
    }

    private var topGradientView: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .blur(radius: Constants.materialBlurRadius)
            .offset(y: Constants.topMaterialOffset)
            .preferredColorScheme(.dark)
            .opacity(Constants.topMaterialOpacity)
    }

    private var recordingOrb: some View {
        VStack {
            Image(systemSymbol: .waveform)
                .font(.title)
                .symbolEffect(.variableColor.iterative.dimInactiveLayers.reversing, options: .repeat(.continuous))
                .padding()
        }
        .glassEffect(.clear.interactive(), in: .circle)
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isRecording = false
            }
        }
        .sensoryFeedback(.warning, trigger: isRecording)
        .sensoryFeedback(.success, trigger: !isRecording)
    }
    
    private var inputControls: some View {
        GlassEffectContainer {
            HStack(spacing: DesignSystem.Spaces.one) {
                // Text input field
                TextField("Ask me anything...", text: $inputText)
                    .focused($isTextFieldFocused)
                    .foregroundColor(.white)
                    .tint(.blue)
                    .padding(.leading, Constants.horizontalPadding)
                    .frame(height: Constants.textFieldHeight)
                    .glassEffect(.clear.interactive(), in: .capsule)
                    .padding(.leading, Constants.horizontalPadding)

                if inputText.isEmpty {
                    Button(action: {
                        withAnimation(.spring(response: Constants.recordingSpringResponse, dampingFraction: Constants.recordingSpringDamping)) {
                            isRecording = true
                        }
                    }) {
                        Image(systemSymbol: .micFill)
                            .font(.title3)
                            .foregroundColor(.white.opacity(Constants.buttonTextOpacity))
                            .padding()
                            .glassEffect(.clear.interactive(), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .frame(width: Constants.buttonWidth)
                    .padding(.trailing, Constants.horizontalPadding)
                } else {
                    Button(action: {
                        withAnimation(.spring(response: Constants.sendSpringResponse)) {
                            // Send action
                            inputText = ""
                        }
                    }) {
                        Image(systemSymbol: .arrowUp)
                            .font(.title3)
                            .foregroundColor(.white.opacity(Constants.buttonTextOpacity))
                            .padding()
                            .glassEffect(.clear.interactive(), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .frame(width: Constants.buttonWidth)
                    .padding(.trailing, Constants.horizontalPadding)
                }
            }
            .padding(.vertical, Constants.inputVerticalPadding)

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
    case midnight = "Midnight"
    case aurora = "Aurora"
    case sunset = "Sunset"
    case ocean = "Ocean"
    case forest = "Forest"
    case galaxy = "Galaxy"
    case lavender = "Lavender"
    case ember = "Ember"
    
    var id: String { rawValue }
    
    var gradientColors: [Color] {
        switch self {
        case .midnight:
            return [
                Color(red: 0.05, green: 0.05, blue: 0.15),
                Color(red: 0.1, green: 0.05, blue: 0.2),
                Color(red: 0.05, green: 0.1, blue: 0.25)
            ]
        case .aurora:
            return [
                Color(red: 0.0, green: 0.15, blue: 0.2),
                Color(red: 0.1, green: 0.2, blue: 0.3),
                Color(red: 0.0, green: 0.25, blue: 0.25)
            ]
        case .sunset:
            return [
                Color(red: 0.2, green: 0.05, blue: 0.15),
                Color(red: 0.25, green: 0.1, blue: 0.15),
                Color(red: 0.15, green: 0.05, blue: 0.2)
            ]
        case .ocean:
            return [
                Color(red: 0.0, green: 0.1, blue: 0.2),
                Color(red: 0.0, green: 0.15, blue: 0.25),
                Color(red: 0.05, green: 0.2, blue: 0.3)
            ]
        case .forest:
            return [
                Color(red: 0.05, green: 0.15, blue: 0.1),
                Color(red: 0.1, green: 0.2, blue: 0.15),
                Color(red: 0.05, green: 0.15, blue: 0.2)
            ]
        case .galaxy:
            return [
                Color(red: 0.1, green: 0.05, blue: 0.2),
                Color(red: 0.15, green: 0.05, blue: 0.25),
                Color(red: 0.2, green: 0.1, blue: 0.3)
            ]
        case .lavender:
            return [
                Color(red: 0.15, green: 0.1, blue: 0.2),
                Color(red: 0.18, green: 0.12, blue: 0.25),
                Color(red: 0.2, green: 0.15, blue: 0.3)
            ]
        case .ember:
            return [
                Color(red: 0.2, green: 0.08, blue: 0.05),
                Color(red: 0.25, green: 0.1, blue: 0.08),
                Color(red: 0.2, green: 0.12, blue: 0.1)
            ]
        }
    }
    
    var orbColors: (Color, Color) {
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
        }
    }
}

// MARK: - Mock Data
struct MockMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

// MARK: - Preview
//@available(iOS 26.0, *)
//#Preview("Midnight Theme") {
//    ModernAssistView()
//}
//
//@available(iOS 26.0, *)
//#Preview("Aurora Theme") {
//    ModernAssistView(selectedTheme: .aurora)
//}
//
//@available(iOS 26.0, *)
//#Preview("Sunset Theme") {
//    ModernAssistView(selectedTheme: .sunset)
//}

@available(iOS 26.0, *)
#Preview("Ocean Theme") {
    ModernAssistView(selectedTheme: .ocean)
}
//
//@available(iOS 26.0, *)
//#Preview("Forest Theme") {
//    ModernAssistView(selectedTheme: .forest)
//}
//
//@available(iOS 26.0, *)
//#Preview("Galaxy Theme") {
//    ModernAssistView(selectedTheme: .galaxy)
//}
//
//@available(iOS 26.0, *)
//#Preview("Lavender Theme") {
//    ModernAssistView(selectedTheme: .lavender)
//}
//
//@available(iOS 26.0, *)
//#Preview("Ember Theme") {
//    ModernAssistView(selectedTheme: .ember)
//}
//
