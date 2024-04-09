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
                pipelinesPicker
                chatList
                bottomBar
            }
            .navigationTitle("Assist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    closeButton
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            assistSession.inProgress = true
            viewModel.onAppear()
        }
        .onDisappear {
            assistSession.inProgress = false
            viewModel.onDisappear()
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
    }

    private var pickerMaxWidth: CGFloat? {
        Current.isCatalyst ? 320 : nil
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
            .frame(maxWidth: pickerMaxWidth)
            .tint(.gray)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 25))
        .padding(.bottom)
    }

    private func makeChatBubble(item: AssistChatItem) -> some View {
        Text(item.content)
            .padding(8)
            .padding(.horizontal, 8)
            .background(backgroundForChatItemType(item.itemType))
            .roundedCorner(10, corners: roundedCornersForChatItemType(item.itemType))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: alignmentForChatItemType(item.itemType))
            .textSelection(.enabled)
    }

    private var chatList: some View {
        ZStack(alignment: .bottom) {
            ZStack(alignment: .top) {
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
                linearGradientDivider(position: .top)
            }
            linearGradientDivider(position: .bottom)
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
    }

    private var assistMicButton: some View {
        Button(action: {
            isFirstResponder = false
            feedbackGenerator.notificationOccurred(.warning)
            if viewModel.isRecording {
                viewModel.stopStreaming()
            } else {
                viewModel.assistWithAudio()
            }
        }, label: {
            micIcon
        })
        .buttonStyle(.plain)
        .font(.system(size: viewModel.isRecording ? 70 : iconSize.width))
        .padding(viewModel.isRecording ? [] : .trailing)
        .animation(.smooth, value: viewModel.isRecording)
        .onChange(of: viewModel.isRecording) { newValue in
            if !newValue {
                feedbackGenerator.notificationOccurred(.success)
            }
        }
    }

    private var sendIcon: some View {
        Image(uiImage: MaterialDesignIcons.sendIcon.image(ofSize: iconSize, color: iconColor))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Color.asset(Asset.Colors.haPrimary))
    }

    @ViewBuilder
    private var micIcon: some View {
        let icon = MaterialDesignIcons.microphoneIcon.image(ofSize: iconSize, color: iconColor)
        if #available(iOS 17.0, *) {
            ZStack {
                Image(systemName: "waveform.circle.fill")
                    .symbolEffect(
                        .variableColor.cumulative.dimInactiveLayers.nonReversing,
                        options: .repeating,
                        value: viewModel.isRecording
                    )
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.asset(Asset.Colors.haPrimary))
                    .opacity(viewModel.isRecording ? 1 : 0)
                Image(uiImage: icon)
                    .opacity(viewModel.isRecording ? 0 : 1)
            }
        } else {
            if viewModel.isRecording {
                Image(systemName: "stop.circle")
            } else {
                Image(uiImage: icon)
            }
        }
    }

    private func backgroundForChatItemType(_ itemType: AssistChatItem.ItemType) -> Color {
        switch itemType {
        case .input:
            .asset(Asset.Colors.haPrimary)
        case .output:
            .gray
        case .error:
            .red
        case .info:
            .gray.opacity(0.5)
        }
    }

    private func alignmentForChatItemType(_ itemType: AssistChatItem.ItemType) -> Alignment {
        switch itemType {
        case .input:
            .trailing
        case .output:
            .leading
        case .error, .info:
            .center
        }
    }

    private func roundedCornersForChatItemType(_ itemType: AssistChatItem.ItemType) -> UIRectCorner {
        switch itemType {
        case .input:
            [.topLeft, .topRight, .bottomLeft]
        case .output:
            [.topLeft, .topRight, .bottomRight]
        case .error, .info:
            [.allCorners]
        }
    }
}
