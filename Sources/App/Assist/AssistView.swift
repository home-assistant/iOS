import SFSafeSymbols
import Shared
import SwiftUI

struct AssistView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AssistViewModel
    @StateObject private var assistSession = AssistSession.shared
    @FocusState private var isFirstResponder: Bool

    private let iconSize: CGSize = .init(width: 28, height: 28)
    private let iconColor: UIColor = .gray
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    private var isIpad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    init(viewModel: AssistViewModel) {
        self._viewModel = .init(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: .zero) {
                if !Current.isCatalyst {
                    pipelinesPicker
                }
                chatList
                bottomBar
            }
            .navigationTitle("Assist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    closeButton
                }

                #if targetEnvironment(macCatalyst)
                ToolbarItem(placement: .topBarTrailing) {
                    macPicker
                }
                #endif
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            assistSession.inProgress = true
            viewModel.initialRoutine()
        }
        .onChange(of: viewModel.focusOnInput) { newValue in
            if newValue {
                isFirstResponder = true
            }
        }
        .onDisappear {
            assistSession.inProgress = false
            viewModel.onDisappear()
        }
        .alert(isPresented: $viewModel.showError) {
            .init(
                title: Text(L10n.errorLabel),
                message: Text(viewModel.errorMessage),
                dismissButton: .default(Text(L10n.okLabel))
            )
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
        }
        .buttonStyle(.plain)
        .tint(Color(uiColor: .label))
        .keyboardShortcut(.cancelAction)
    }

    private var pipelinesPicker: some View {
        VStack {
            Picker(L10n.Assist.PipelinesPicker.title, selection: $viewModel.preferredPipelineId) {
                ForEach(viewModel.pipelines, id: \.id) { pipeline in
                    Text(pipeline.name)
                        .font(.footnote)
                        .tag(pipeline.id)
                }
            }
            .pickerStyle(.menu)
            .tint(.gray)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .padding(.bottom)
    }

    private var macPicker: some View {
        VStack {
            Picker(L10n.Assist.PipelinesPicker.title, selection: $viewModel.preferredPipelineId) {
                ForEach(viewModel.pipelines, id: \.id) { pipeline in
                    Text(pipeline.name)
                        .font(.footnote)
                        .tag(pipeline.id)
                }
            }
            .pickerStyle(.menu)
        }
        .frame(maxWidth: 200, alignment: .trailing)
    }

    private func makeChatBubble(item: AssistChatItem) -> some View {
        VStack {
            if item.itemType == .typing {
                AssistTypingIndicator()
                    .padding(.vertical, Spaces.half)
            } else {
                Text(item.content)
            }
        }
        .padding(8)
        .padding(.horizontal, 8)
        .background(backgroundForChatItemType(item.itemType))
        .roundedCorner(10, corners: roundedCornersForChatItemType(item.itemType))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, alignment: alignmentForChatItemType(item.itemType))
        .textSelection(.enabled)
    }

    private var chatList: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack {
                    ForEach(viewModel.chatItems, id: \.id) { item in
                        makeChatBubble(item: item)
                            .id(item.id)
                            .padding(.bottom)
                    }
                }
                .padding()
                .onChange(of: viewModel.chatItems) { _ in
                    proxy.scrollTo(viewModel.chatItems.last?.id)
                }
            }
        }
    }

    /// Position is where it will be placed related to the list
    private func linearGradientDivider(position: UnitPoint) -> some View {
        VStack {}
            .frame(maxWidth: .infinity)
            .frame(height: 22)
            .background(LinearGradient(colors: [
                Color(uiColor: .systemBackground),
                .clear,
            ], startPoint: position, endPoint: position == .top ? .bottom : .top))
    }

    private var bottomBar: some View {
        ZStack {
            HStack(spacing: Spaces.two) {
                TextField("", text: $viewModel.inputText)
                    .textFieldStyle(.plain)
                    .focused($isFirstResponder)
                    .frame(maxWidth: viewModel.isRecording ? 0 : .infinity)
                    .frame(height: 45)
                    .padding(.horizontal, viewModel.isRecording ? .zero : Spaces.two)
                    .overlay(content: {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.gray)
                    })
                    .opacity(viewModel.isRecording ? 0 : 1)
                    .animation(.smooth, value: viewModel.isRecording)
                    .onSubmit {
                        viewModel.assistWithText()
                    }
                if viewModel.inputText.isEmpty {
                    assistMicButton
                } else {
                    assistSendTextButton
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spaces.two)
            .padding(.vertical)
            .padding(.bottom, isIpad ? Spaces.two : Spaces.half)
            .background(viewModel.isRecording ? .clear : Color(uiColor: .systemBackground))
            .opacity(viewModel.isRecording ? 0 : 1)
            Button {
                feedbackGenerator.notificationOccurred(.warning)
                viewModel.stopStreaming()
            } label: {
                AssistMicAnimationView()
                    .frame(maxWidth: viewModel.isRecording ? .infinity : 0)
            }
            .buttonStyle(.plain)
            .opacity(viewModel.isRecording ? 1 : 0)
        }
    }

    private var assistSendTextButton: some View {
        Button(action: {
            viewModel.assistWithText()
        }, label: {
            sendIcon
        })
        .buttonStyle(.plain)
        .frame(maxWidth: viewModel.isRecording ? 0 : nil)
        .opacity(viewModel.isRecording ? 0 : 1)
        .font(.system(size: 32))
        .tint(Color.asset(Asset.Colors.haPrimary))
        .animation(.smooth, value: viewModel.isRecording)
        .keyboardShortcut(.defaultAction)
    }

    @ViewBuilder
    private var assistMicButton: some View {
        Button(action: {
            feedbackGenerator.notificationOccurred(.success)
            isFirstResponder = false
            viewModel.assistWithAudio()
        }, label: {
            Image(uiImage: MaterialDesignIcons.microphoneIcon.image(ofSize: iconSize, color: iconColor))
        })
        .buttonStyle(.plain)
        .font(.system(size: iconSize.width))
        .padding(.trailing)
        .animation(.smooth, value: viewModel.isRecording)
    }

    private var sendIcon: some View {
        Image(uiImage: MaterialDesignIcons.sendIcon.image(ofSize: iconSize, color: iconColor))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Color.asset(Asset.Colors.haPrimary))
    }

    private func backgroundForChatItemType(_ itemType: AssistChatItem.ItemType) -> Color {
        switch itemType {
        case .input:
            .asset(Asset.Colors.haPrimary)
        case .output:
            .gray
        case .error:
            .red
        case .info, .typing:
            .gray.opacity(0.5)
        }
    }

    private func alignmentForChatItemType(_ itemType: AssistChatItem.ItemType) -> Alignment {
        switch itemType {
        case .input:
            .trailing
        case .output, .typing:
            .leading
        case .error, .info:
            .center
        }
    }

    private func roundedCornersForChatItemType(_ itemType: AssistChatItem.ItemType) -> UIRectCorner {
        switch itemType {
        case .input:
            [.topLeft, .topRight, .bottomLeft]
        case .output, .typing:
            [.topLeft, .topRight, .bottomRight]
        case .error, .info:
            [.allCorners]
        }
    }
}
