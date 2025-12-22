import SwiftUI

@available(iOS 26.0, *)
struct ModernAssistView: View {
    @State private var isRecording = false
    @State private var inputText = ""
    @State private var pulseAnimation = false
    @State private var glowIntensity: CGFloat = 0
    @FocusState private var isTextFieldFocused: Bool
    
    // Sample chat messages for preview
    @State private var messages: [MockMessage] = [
        MockMessage(text: "Hello! How can I help you today?", isUser: false),
        MockMessage(text: "What's the weather like?", isUser: true),
        MockMessage(text: "I'll check the weather for you. The current temperature is 72°F with clear skies.", isUser: false)
    ]
    
    var body: some View {
        ZStack {
            // Animated background gradient
            backgroundGradient
            
            VStack(spacing: 0) {
                // Header
                modernHeader
                
                // Chat area
                chatArea
                
                // Input area
                modernInputArea
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            startAmbientAnimation()
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.15),
                Color(red: 0.1, green: 0.05, blue: 0.2),
                Color(red: 0.05, green: 0.1, blue: 0.25)
            ],
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
                                    Color.blue.opacity(0.3),
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
                                    Color.purple.opacity(0.3),
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
                
                Text("AI Assistant")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.1))
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 60)
        .padding(.bottom, 20)
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
        VStack(spacing: 0) {
            // Visual separator with glow
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.1),
                            .white.opacity(0.05)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .shadow(color: .blue.opacity(0.3), radius: 4, y: -2)
            
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
            .background(.ultraThinMaterial.opacity(0.5))
        }
    }
    
    private var recordingOrb: some View {
        VStack(spacing: 12) {
            ZStack {
                // Outer glow rings
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .blue.opacity(0.6),
                                    .purple.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 60 + CGFloat(index) * 20, height: 60 + CGFloat(index) * 20)
                        .opacity(pulseAnimation ? 0 : 0.6)
                        .scaleEffect(pulseAnimation ? 1.5 : 1)
                }
                
                // Main orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white,
                                .blue,
                                .purple
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: .blue.opacity(0.8), radius: 20)
                    .shadow(color: .purple.opacity(0.8), radius: 30)
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.title2)
                            .foregroundColor(.white)
                            .symbolEffect(.variableColor.iterative, isActive: isRecording)
                    )
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
            }
            
            Text("Listening...")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isRecording = false
            }
        }
    }
    
    private var inputControls: some View {
        HStack(spacing: 12) {
            // Text input field
            HStack(spacing: 12) {
                TextField("Ask me anything...", text: $inputText)
                    .focused($isTextFieldFocused)
                    .foregroundColor(.white)
                    .tint(.blue)
                    .padding(.leading, 20)
                
                if !inputText.isEmpty {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            // Send action
                            inputText = ""
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .blue.opacity(0.5), radius: 8)
                    }
                } else {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            isRecording = true
                        }
                    }) {
                        Image(systemName: "mic.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(isTextFieldFocused ? 0.4 : 0.2),
                                        .white.opacity(isTextFieldFocused ? 0.2 : 0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: isTextFieldFocused ? .blue.opacity(0.3) : .clear, radius: 12)
            )
            .padding(.horizontal, 20)
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

// MARK: - Mock Data
struct MockMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

// MARK: - Preview
@available(iOS 26.0, *)
#Preview {
    ModernAssistView()
}
