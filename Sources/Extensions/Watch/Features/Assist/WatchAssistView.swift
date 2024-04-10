import SwiftUI
import Shared

struct WatchAssistView<ViewModel>: View where ViewModel: WatchAssistViewModelProtocol {
    @StateObject private var viewModel: ViewModel

    init(viewModel: ViewModel) {
        self._viewModel = .init(wrappedValue: viewModel)
    }

    var body: some View {
        VStack {
            chatList
            bottomBar
        }
    }

    private var chatList: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack {
                    ForEach(viewModel.chatItems, id: \.id) { item in
                        ChatBubbleView(item: item)
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

    private var bottomBar: some View {
        Button(action: {

        }, label: {
            Image(uiImage: MaterialDesignIcons.microphoneIcon.image(ofSize: .init(width: 24, height: 24), color: .init(asset: Asset.Colors.haPrimary)))
        })
    }
}

#if DEBUG
#Preview {
    WatchAssistView(viewModel: MockWatchAssistViewModel())
}

final class MockWatchAssistViewModel: WatchAssistViewModelProtocol {
    var chatItems: [AssistChatItem] = []
    var preferredPipelineId: String = ""
    var showScreenLoader: Bool = false
    var inputText: String = ""
    var isRecording: Bool = false

}
#endif
