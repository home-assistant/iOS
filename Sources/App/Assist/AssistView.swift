import GRDB
import SFSafeSymbols
import Shared
import SwiftUI

struct AssistView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AssistViewModel
    @StateObject private var assistSession = AssistSession.shared
    @FocusState private var isFirstResponder: Bool
    @State private var showSettings = false
    @State private var bottomBarWidth: CGFloat = .zero

    private enum Constants {
        static let iconSize = CGSize(width: 28, height: 28)
        static let iconColor: UIColor = .white
        static let borderWidth: CGFloat = DesignSystem.Border.Width.default

        static let macPipelinePickerMaxWidth: CGFloat = 200

        static let bubbleCornerRadius: CGFloat = DesignSystem.CornerRadius.oneAndMicro
        static let pendingBubbleStroke = StrokeStyle(lineWidth: 1.5, dash: [5, 3])
        static let infoBubbleBackgroundOpacity: Double = 0.5

        static let listFadeHeight: CGFloat = 22

        static let bottomBarMaxHeight: CGFloat = 80
        /// Inset of everything in the bottom bar from the screen edges: input row, orb and keyboard
        /// button all share it, so the bar reads as one row in both states.
        static let barHorizontalPadding: CGFloat = DesignSystem.Spaces.three
        /// How eagerly the text field and the action button glass shapes merge into one container.
        static let inputRowGlassSpacing: CGFloat = DesignSystem.Spaces.two
        /// Gap under the bottom bar, on top of the bottom safe area. Negative values reach into the
        /// safe area, which is how the row sits closer to the screen edge than the inset alone allows.
        static let inputRowBottomPadding: CGFloat = -DesignSystem.Spaces.one
        static let inputFieldHeight: CGFloat = 40
        static let inputActionButtonHeight: CGFloat = 40
        /// Height of the input row, driven by its tallest element (the action button plus its padding).
        /// The recording state claims the same height, so the orb lands on the mic button's line.
        static let inputRowHeight: CGFloat = inputActionButtonHeight + DesignSystem.Spaces.oneAndHalf * 2
        /// Distance from the bar's trailing edge to the centre of the input row's mic button: half the
        /// button plus its own padding plus the row inset. The orb travels between there and the centre,
        /// so the mic reads as one button sliding in and out of the middle.
        static let micButtonCenterInsetFromTrailing: CGFloat = inputActionButtonHeight / 2
            + DesignSystem.Spaces.oneAndHalf
            + barHorizontalPadding
        static let sendIconFontSize: CGFloat = 32
        static let keyboardButtonSize: CGFloat = 44
        static let keyboardIconFontSize: CGFloat = 18

        static let recordingTransition: Animation = .smooth
    }

    private let feedbackGenerator = UINotificationFeedbackGenerator()

    private let showCloseButton: Bool
    /// Renders the pre-iOS 26 materials instead of Liquid Glass, so the legacy look stays previewable.
    private let forcesLegacyAppearance: Bool

    init(viewModel: AssistViewModel, showCloseButton: Bool = true, forcesLegacyAppearance: Bool = false) {
        self._viewModel = .init(wrappedValue: viewModel)
        self.showCloseButton = showCloseButton
        self.forcesLegacyAppearance = forcesLegacyAppearance
    }

    var body: some View {
        content
            .onAppear {
                assistSession.inProgress = true
                viewModel.initialRoutine()
                viewModel.subscribeForConfigChanges()
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
                    title: Text(verbatim: L10n.errorLabel),
                    message: Text(viewModel.errorMessage),
                    dismissButton: .default(Text(verbatim: L10n.okLabel))
                )
            }
    }

    // MARK: - Configuration Persistence

    private var content: some View {
        NavigationView {
            VStack(spacing: .zero) {
                if !Current.isCatalyst {
                    pipelinesPicker
                }
                chatList
            }
            .navigationTitle("Assist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if showCloseButton {
                        closeButton
                    }
                }

                #if !targetEnvironment(macCatalyst)
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26.0, *) {
                        settingsButton
                    }
                }
                #endif

                #if targetEnvironment(macCatalyst)
                ToolbarItem(placement: .topBarTrailing) {
                    macPicker
                }
                #endif
            }
            .sheet(isPresented: $showSettings) {
                if #available(iOS 26.0, *) {
                    AssistSettingsView()
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemSymbol: .xmark)
        }
        .buttonStyle(.plain)
        .tint(Color(uiColor: .label))
        .keyboardShortcut(.cancelAction)
    }

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemSymbol: .gearshapeFill)
        }
        .buttonStyle(.plain)
        .tint(Color(uiColor: .label))
    }

    private var pipelinesPicker: some View {
        Picker(L10n.Assist.PipelinesPicker.title, selection: $viewModel.preferredPipelineId) {
            ForEach(viewModel.pipelines, id: \.id) { pipeline in
                Text(pipeline.name)
                    .font(.footnote)
                    .tag(pipeline.id)
            }
        }
        .pickerStyle(.menu)
        .tint(.gray)
        .modify { view in
            if #available(iOS 26.0, *), !forcesLegacyAppearance {
                view.glassEffect(.regular.interactive(), in: .capsule)
            } else {
                view.background(.regularMaterial, in: Capsule())
            }
        }
        .padding(.bottom)
    }

    private var macPicker: some View {
        Menu {
            Picker(L10n.Assist.PipelinesPicker.title, selection: $viewModel.preferredPipelineId) {
                ForEach(viewModel.pipelines, id: \.id) { pipeline in
                    Text(pipeline.name)
                        .tag(pipeline.id)
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spaces.half) {
                Text(selectedPipelineName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemSymbol: .chevronUpChevronDown)
            }
        }
        .frame(maxWidth: Constants.macPipelinePickerMaxWidth, alignment: .trailing)
    }

    private var selectedPipelineName: String {
        viewModel.pipelines.first { $0.id == viewModel.preferredPipelineId }?.name
            ?? L10n.Assist.PipelinesPicker.title
    }

    private func makeChatBubble(item: AssistChatItem) -> some View {
        VStack {
            if item.itemType == .typing {
                AssistTypingIndicator()
                    .padding(.vertical, DesignSystem.Spaces.half)
            } else {
                Text(item.markdown)
            }
        }
        .padding(DesignSystem.Spaces.one)
        .padding(.horizontal, DesignSystem.Spaces.one)
        .background(backgroundForChatItemType(item.itemType))
        .roundedCorner(Constants.bubbleCornerRadius, corners: roundedCornersForChatItemType(item.itemType))
        .overlay {
            if item.itemType == .pending {
                RoundedCorner(
                    radius: Constants.bubbleCornerRadius,
                    corners: roundedCornersForChatItemType(item.itemType)
                )
                .stroke(Color.haPrimary, style: Constants.pendingBubbleStroke)
            }
        }
        .foregroundColor(foregroundForChatItemType(item.itemType))
        .tint(tintForChatItemType(item.itemType))
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
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
    }

    /// Position is where it will be placed related to the list
    private func linearGradientDivider(position: UnitPoint) -> some View {
        VStack {}
            .frame(maxWidth: .infinity)
            .frame(height: Constants.listFadeHeight)
            .background(LinearGradient(colors: [
                Color(uiColor: .systemBackground),
                .clear,
            ], startPoint: position, endPoint: position == .top ? .bottom : .top))
    }

    private var bottomBar: some View {
        ZStack {
            inputTextView
            recordingView
        }
        .frame(maxHeight: Constants.bottomBarMaxHeight, alignment: .bottom)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { bottomBarWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { newValue in bottomBarWidth = newValue }
            }
        }
    }

    private var inputTextView: some View {
        HStack(spacing: DesignSystem.Spaces.two) {
            inputTextField
            inputActionButton
        }
        .modify { view in
            if #available(iOS 26.0, *), !forcesLegacyAppearance {
                GlassEffectContainer(spacing: Constants.inputRowGlassSpacing) {
                    view
                }
            } else {
                view
            }
        }
        .padding(.horizontal, Constants.barHorizontalPadding)
        .padding(.bottom, Constants.inputRowBottomPadding)
        .opacity(viewModel.isRecording ? 0 : 1)
        .allowsHitTesting(!viewModel.isRecording)
        .animation(Constants.recordingTransition, value: viewModel.isRecording)
    }

    private var inputTextField: some View {
        TextField(L10n.Assist.TextField.placeholder, text: $viewModel.inputText)
            .textFieldStyle(.plain)
            .focused($isFirstResponder)
            .onSubmit {
                viewModel.assistWithText()
                if Current.isCatalyst {
                    isFirstResponder = true
                }
            }
            .frame(height: Constants.inputFieldHeight)
            .padding(.vertical, DesignSystem.Spaces.one)
            .padding(.horizontal, DesignSystem.Spaces.two)
            .modify { view in
                if #available(iOS 26.0, *), !forcesLegacyAppearance {
                    view.glassEffect(.regular.interactive(), in: .capsule)
                } else {
                    view
                        .background(.regularMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(.tileBorder, lineWidth: Constants.borderWidth))
                }
            }
    }

    private var inputActionButton: some View {
        Group {
            if viewModel.inputText.isEmpty {
                assistMicButton
            } else {
                assistSendTextButton
            }
        }
        .frame(height: Constants.inputActionButtonHeight)
        .padding(DesignSystem.Spaces.oneAndHalf)
        .modify { view in
            if #available(iOS 26.0, *), !forcesLegacyAppearance {
                view.glassEffect(.regular.interactive().tint(.haPrimary), in: .circle)
            } else {
                view
                    .background(.haPrimary, in: Circle())
                    .overlay(Circle().strokeBorder(.tileBorder, lineWidth: Constants.borderWidth))
            }
        }
    }

    private var recordingView: some View {
        ZStack {
            Button {
                feedbackGenerator.notificationOccurred(.warning)
                viewModel.assistWithAudio()
            } label: {
                AssistVoiceOrbView(level: viewModel.audioLevel)
            }
            .buttonStyle(.plain)
            .offset(x: viewModel.isRecording ? .zero : idleOrbOffsetX)

            HStack {
                Spacer()
                keyboardButton
            }
            .padding(.trailing, Constants.barHorizontalPadding)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Constants.inputRowHeight)
        .padding(.bottom, Constants.inputRowBottomPadding)
        .opacity(viewModel.isRecording ? 1 : 0)
        .allowsHitTesting(viewModel.isRecording)
        .animation(Constants.recordingTransition, value: viewModel.isRecording)
    }

    /// Parks the orb over the input row's mic button while idle, so starting a recording slides it to
    /// the centre of the bar and stopping one slides it back.
    private var idleOrbOffsetX: CGFloat {
        guard bottomBarWidth > Constants.micButtonCenterInsetFromTrailing * 2 else { return .zero }
        return bottomBarWidth / 2 - Constants.micButtonCenterInsetFromTrailing
    }

    private var keyboardButton: some View {
        Button {
            feedbackGenerator.notificationOccurred(.success)
            viewModel.stopStreaming()
            isFirstResponder = true
        } label: {
            Image(systemSymbol: .keyboard)
                .font(.system(size: Constants.keyboardIconFontSize, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: Constants.keyboardButtonSize, height: Constants.keyboardButtonSize)
        }
        .buttonStyle(.plain)
        .modify { view in
            if #available(iOS 26.0, *), !forcesLegacyAppearance {
                view.glassEffect(.regular.interactive(), in: .circle)
            } else {
                view
                    .background(.regularMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(.tileBorder, lineWidth: Constants.borderWidth))
            }
        }
    }

    private var assistSendTextButton: some View {
        Button(action: {
            viewModel.assistWithText()
        }, label: {
            sendIcon
        })
        .buttonStyle(.plain)
        .font(.system(size: Constants.sendIconFontSize))
        .tint(Color.haPrimary)
        .keyboardShortcut(.defaultAction)
    }

    @ViewBuilder
    private var assistMicButton: some View {
        Button(action: {
            assistMicButtonAction()
        }, label: {
            Image(uiImage: MaterialDesignIcons.microphoneIcon.image(
                ofSize: Constants.iconSize,
                color: Constants.iconColor
            ))
        })
        .buttonStyle(.plain)
        .keyboardShortcut(.init("a"))
        .font(.system(size: Constants.iconSize.width))
    }

    private func assistMicButtonAction() {
        feedbackGenerator.notificationOccurred(.success)
        isFirstResponder = false

        viewModel.assistWithAudio()
    }

    private var sendIcon: some View {
        Image(uiImage: MaterialDesignIcons.sendIcon.image(ofSize: Constants.iconSize, color: Constants.iconColor))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Color.haPrimary)
    }

    private func backgroundForChatItemType(_ itemType: AssistChatItem.ItemType) -> Color {
        switch itemType {
        case .input:
            .haPrimary
        case .output, .typing:
            .secondaryBackground
        case .error:
            .red
        case .info:
            .gray.opacity(Constants.infoBubbleBackgroundOpacity)
        case .pending:
            .clear
        }
    }

    private func foregroundForChatItemType(_ itemType: AssistChatItem.ItemType) -> Color {
        switch itemType {
        case .input, .error:
            .white
        case .info:
            .secondary
        default:
            .primary
        }
    }

    private func tintForChatItemType(_ itemType: AssistChatItem.ItemType) -> Color {
        switch itemType {
        case .input, .error:
            .white
        default:
            .haPrimary
        }
    }

    private func alignmentForChatItemType(_ itemType: AssistChatItem.ItemType) -> Alignment {
        switch itemType {
        case .input, .pending:
            .trailing
        case .output, .typing:
            .leading
        case .error, .info:
            .center
        }
    }

    private func roundedCornersForChatItemType(_ itemType: AssistChatItem.ItemType) -> UIRectCorner {
        switch itemType {
        case .input, .pending:
            [.topLeft, .topRight, .bottomLeft]
        case .output, .typing:
            [.topLeft, .topRight, .bottomRight]
        case .error, .info:
            [.allCorners]
        }
    }
}

private func previewRecordingViewModel() -> AssistViewModel {
    let viewModel = AssistViewModel(
        server: ServerFixture.standard,
        audioRecorder: AudioRecorder(),
        audioPlayer: AudioPlayer(),
        assistService: AssistService(server: ServerFixture.standard),
        autoStartRecording: false
    )
    viewModel.isRecording = true
    viewModel.audioLevel = 0.6
    return viewModel
}

#Preview("Text mode") {
    AssistView.build(server: ServerFixture.standard)
}

#Preview("Text mode (legacy)") {
    AssistView.build(server: ServerFixture.standard, forcesLegacyAppearance: true)
}

#Preview("Recording") {
    AssistView(viewModel: previewRecordingViewModel())
}

#Preview("Recording (legacy)") {
    AssistView(viewModel: previewRecordingViewModel(), forcesLegacyAppearance: true)
}
