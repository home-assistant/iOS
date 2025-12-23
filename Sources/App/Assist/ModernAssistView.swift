import SwiftUI
import Shared

@available(iOS 26.0, *)
struct ModernAssistView: View {
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
                                    selectedTheme.orbColors.0.opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .offset(x: -100, y: pulseAnimation ? -50 : 50)
                        .blur(radius: 40)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    selectedTheme.orbColors.1.opacity(0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .offset(x: geometry.size.width - 100, y: pulseAnimation ? 100 : 0)
                        .blur(radius: 40)
                }
            }
        }
    }
    
    // MARK: - Header
    private var modernHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Assist")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
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
                .offset(x: -5)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 60)
        .padding(.bottom, 20)
        .background(topGradientView)
    }
    
    // MARK: - Chat Area
    private var chatArea: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(messages) { message in
                    modernMessageBubble(message: message)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
    
    private func modernMessageBubble(message: MockMessage) -> some View {
        HStack {
            if message.isUser { Spacer(minLength: 40) }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 0) {
                Text(message.text)
                    .font(.body)
                    .foregroundColor(message.isUser ? .white : .white.opacity(0.95))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        ZStack {
                            if message.isUser {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.blue,
                                                Color.blue.opacity(0.8)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        .white.opacity(0.3),
                                                        .white.opacity(0.1)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                            }
                        }
                    )
            }
            
            if !message.isUser { Spacer(minLength: 40) }
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
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .ignoresSafeArea()
        .background(
            bottomGradientView
        )
    }

    private var bottomGradientView: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .blur(radius: 20)
            .offset(y: 20)
            .preferredColorScheme(.dark)
            .opacity(0.9)
    }

    private var topGradientView: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .blur(radius: 20)
            .offset(y: 0)
            .preferredColorScheme(.dark)
            .opacity(0.5)
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
        HStack(spacing: DesignSystem.Spaces.one) {
            // Text input field
            TextField("Ask me anything...", text: $inputText)
                .focused($isTextFieldFocused)
                .foregroundColor(.white)
                .tint(.blue)
                .padding(.leading, 20)
                .frame(height: 50)
                .glassEffect(.clear.interactive(), in: .capsule)
                .padding(.leading, 20)
            
            if inputText.isEmpty {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        isRecording = true
                    }
                }) {
                    Image(systemSymbol: .micFill)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                        .padding()
                        .glassEffect(.clear, in: .capsule)
                }
                .buttonStyle(.plain)
                .frame(width: 60)
                .padding(.trailing, 20)
            } else {
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        // Send action
                        inputText = ""
                    }
                }) {
                    Image(systemSymbol: .arrowUp)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                        .padding()
                        .glassEffect(.clear, in: .capsule)
                }
                .buttonStyle(.plain)
                .frame(width: 60)
                .padding(.trailing, 20)
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Animations
    private func startAmbientAnimation() {
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            pulseAnimation = true
        }
        
        // Start recording animation when recording
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
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
