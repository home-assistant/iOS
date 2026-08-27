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
    @Namespace private var micGeometry

    private enum Constants {
        static let iconSize = CGSize(width: 28, height: 28)
        static let iconColor: UIColor = .white
        static let microphoneImage = MaterialDesignIcons.microphoneIcon.image(ofSize: iconSize, color: iconColor)
        static let sendImage = MaterialDesignIcons.sendIcon.image(ofSize: iconSize, color: iconColor)
        static let borderWidth: CGFloat = DesignSystem.Border.Width.default

        static let macPipelinePickerMaxWidth: CGFloat = 200

        static let bubbleCornerRadius: CGFloat = 14
        static let bubbleVerticalPadding: CGFloat = DesignSystem.Spaces.oneAndHalf
        static let bubbleHorizontalPadding: CGFloat = DesignSystem.Spaces.two
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
        /// With the keyboard up the bar sits on its top edge instead of floating over the safe area,
        /// so it tightens against the screen sides and lifts clear of the keyboard.
        static let barHorizontalPaddingKeyboardOpen: CGFloat = DesignSystem.Spaces.oneAndHalf
        static let inputRowBottomPaddingKeyboardOpen: CGFloat = DesignSystem.Spaces.one
        static let inputFieldHeight: CGFloat = 40
        static let inputActionButtonHeight: CGFloat = 40
        /// Height of the input row, driven by its tallest element (the action button plus its padding).
        /// The recording state claims the same height, so the orb lands on the mic button's line.
        static let inputRowHeight: CGFloat = inputActionButtonHeight + DesignSystem.Spaces.oneAndHalf * 2
        /// Ties the input row's mic button and the recording orb together, so one turns into the other
        /// in place instead of cross-fading.
        static let micGeometryID = "assist-mic"
        /// Lifts the orb clear of the keyboard button's line, so the two do not read as one row.
        static let orbVerticalOffset: CGFloat = -DesignSystem.Spaces.two
        static let sendIconFontSize: CGFloat = 32
        static let keyboardButtonSize: CGFloat = 44
        static let keyboardIconFontSize: CGFloat = 18

        static let recordingTransition: Animation = .smooth
        static let keyboardTransition: Animation = .smooth
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

    /// The keyboard pins the bar to its top edge, where the floating insets read as too loose. On Mac
    /// the field keeps focus with no keyboard on screen, so the bar stays as it is.
    private var isKeyboardVisible: Bool {
        isFirstResponder && !Current.isCatalyst
    }

    private var barHorizontalPadding: CGFloat {
        isKeyboardVisible ? Constants.barHorizontalPaddingKeyboardOpen : Constants.barHorizontalPadding
    }

    private var barBottomPadding: CGFloat {
        isKeyboardVisible ? Constants.inputRowBottomPaddingKeyboardOpen : Constants.inputRowBottomPadding
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
        .padding(.vertical, Constants.bubbleVerticalPadding)
        .padding(.horizontal, Constants.bubbleHorizontalPadding)
        .modify { view in
            if #available(iOS 26.0, *), !forcesLegacyAppearance {
                view.glassEffect(
                    .regular.tint(glassTintForChatItemType(item.itemType)),
                    in: RoundedCorner(
                        radius: Constants.bubbleCornerRadius,
                        corners: roundedCornersForChatItemType(item.itemType)
                    )
                )
            } else {
                view
                    .background(backgroundForChatItemType(item.itemType))
                    .roundedCorner(
                        Constants.bubbleCornerRadius,
                        corners: roundedCornersForChatItemType(item.itemType)
                    )
            }
        }
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
        .modify { view in
            if item.itemType == .input {
                view.contextMenu { chatBubbleMenu(for: item) }
            } else {
                view
            }
        }
    }

    /// Offered on the requests the user made, so one can be copied, corrected and sent again, or
    /// simply run a second time.
    @ViewBuilder
    private func chatBubbleMenu(for item: AssistChatItem) -> some View {
        Button {
            UIPasteboard.general.string = item.content
        } label: {
            Label(L10n.copyLabel, systemSymbol: .docOnDoc)
        }

        Button {
            viewModel.inputText = item.content
            isFirstResponder = true
        } label: {
            Label(L10n.Assist.Chat.Menu.edit, systemSymbol: .pencil)
        }

        Button {
            viewModel.inputText = item.content
            viewModel.assistWithText()
        } label: {
            Label(L10n.Assist.Chat.Menu.replay, systemSymbol: .arrowClockwise)
        }
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
        .animation(Constants.recordingTransition, value: viewModel.isRecording)
        .animation(Constants.keyboardTransition, value: isKeyboardVisible)
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
        .padding(.horizontal, barHorizontalPadding)
        .padding(.bottom, barBottomPadding)
        .opacity(viewModel.isRecording ? 0 : 1)
        .allowsHitTesting(!viewModel.isRecording)
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

    @ViewBuilder
    private var inputActionButton: some View {
        if !viewModel.isRecording {
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
            .matchedGeometryEffect(id: Constants.micGeometryID, in: micGeometry)
        }
    }

    private var recordingView: some View {
        ZStack {
            if viewModel.isRecording {
                Button {
                    feedbackGenerator.notificationOccurred(.warning)
                    viewModel.assistWithAudio()
                } label: {
                    AssistVoiceOrbView(
                        level: viewModel.audioLevel,
                        forcesLegacyAppearance: forcesLegacyAppearance
                    )
                }
                .buttonStyle(.plain)
                .matchedGeometryEffect(id: Constants.micGeometryID, in: micGeometry)
                .offset(y: Constants.orbVerticalOffset)
            }

            HStack {
                Spacer()
                keyboardButton
            }
            .padding(.trailing, barHorizontalPadding)
            .opacity(viewModel.isRecording ? 1 : 0)
            .allowsHitTesting(viewModel.isRecording)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Constants.inputRowHeight)
        .padding(.bottom, barBottomPadding)
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
            Image(uiImage: Constants.microphoneImage)
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
        Image(uiImage: Constants.sendImage)
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

    /// `nil` leaves the glass untinted, which is what the pending bubble wants: it is drawn by its
    /// dashed border alone.
    private func glassTintForChatItemType(_ itemType: AssistChatItem.ItemType) -> Color? {
        switch itemType {
        case .pending:
            nil
        default:
            backgroundForChatItemType(itemType)
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

private func previewViewModel(chatItems: [AssistChatItem] = [], isRecording: Bool = false) -> AssistViewModel {
    let viewModel = AssistViewModel(
        server: ServerFixture.standard,
        audioRecorder: AudioRecorder(),
        audioPlayer: AudioPlayer(),
        assistService: AssistService(server: ServerFixture.standard),
        autoStartRecording: false
    )
    viewModel.chatItems = chatItems
    if isRecording {
        viewModel.isRecording = true
        viewModel.audioLevel = 0.6
    }
    return viewModel
}

/// One bubble of every type, so a single preview covers each background, corner set and alignment.
private let previewChatItems: [AssistChatItem] = [
    .init(content: "Turn off the kitchen lights", itemType: .input),
    .init(content: "Turned off **2 lights** in the kitchen.", itemType: .output),
    .init(content: "Pipeline switched to Home Assistant", itemType: .info),
    .init(content: "What is the temperature in the living room?", itemType: .input),
    .init(content: "It is 21.5 degrees, and the heating is off.", itemType: .output),
    .init(content: "Could not reach the server", itemType: .error),
    .init(content: "Set the thermostat to 20", itemType: .pending),
    .init(content: "", itemType: .typing),
]

#Preview("Text mode") {
    AssistView.build(server: ServerFixture.standard)
}

#Preview("Text mode (legacy)") {
    AssistView.build(server: ServerFixture.standard, forcesLegacyAppearance: true)
}

#Preview("Chat") {
    AssistView(viewModel: previewViewModel(chatItems: previewChatItems))
}

#Preview("Chat (legacy)") {
    AssistView(viewModel: previewViewModel(chatItems: previewChatItems), forcesLegacyAppearance: true)
}

#Preview("Chat while recording") {
    AssistView(viewModel: previewViewModel(chatItems: previewChatItems, isRecording: true))
}

#Preview("Recording") {
    AssistView(viewModel: previewViewModel(isRecording: true))
}

#Preview("Recording (legacy)") {
    AssistView(viewModel: previewViewModel(isRecording: true), forcesLegacyAppearance: true)
}
