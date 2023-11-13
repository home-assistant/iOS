//
//  AssistView.swift
//  WatchExtension-Watch
//
//  Created by Bruno Pantaleão on 13/11/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import SwiftUI

@available(watchOS 7.0, *)
class AssistHostingController: WKHostingController<AssistView> {
    override var body: AssistView {
        AssistView(viewModel: .init())
    }
}

@available(watchOS 7.0, *)
struct AssistView: View {

    @ObservedObject private var viewModel: AssistViewModel

    init(viewModel: AssistViewModel) {
        self._viewModel = .init(wrappedValue: viewModel)
    }

    var body: some View {
        chatList
            .ignoresSafeArea(.all, edges: [.bottom])
            .navigationTitle("Assist")
            .onAppear {
                viewModel.requestInput()
            }
    }

    private var chatList: some View {
        VStack(spacing: .zero) {
            ScrollView {
                LazyVStack {
                    ScrollViewReader { scrollView in
                        ForEach(viewModel.chatMessages, id: \.self) { message in
                            if viewModel.chatMessages.last == message {
                                makeChatBubble(text: message.message, sender: message.sender)
                                    .id(0)
                            } else {
                                makeChatBubble(text: message.message, sender: message.sender)
                            }
                        }
                        .onChange(of: viewModel.chatMessages) { _ in
                            withAnimation {
                                scrollView.scrollTo(0)
                            }
                        }
                    }
                }
            }

            assistButton
        }
    }

    private func makeChatBubble(text: String, sender: AssistViewModel.ChatMessage.Sender) -> some View {
        VStack {
            Text(text)
                .frame(alignment: sender == .assist ? .leading : .trailing)
                .padding()
                .background(sender == .assist ? Color.gray : Color.accentColor)
                .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, alignment: sender == .assist ? .leading : .trailing)
        .padding(.bottom)
    }

    private var assistButton: some View {
        VStack {
            Image(systemName: viewModel.microphoneIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(alignment: .center)
                .foregroundColor(.accentColor)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .onTapGesture {
            viewModel.requestInput()
        }
    }
}

@available(watchOS 7.0, *)
#Preview {
    AssistView(viewModel: .init())
}
