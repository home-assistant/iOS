//
//  WatchAssistView.swift
//  WatchApp
//
//  Created by Bruno Pantaleão on 04/06/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import SwiftUI
import Shared

struct WatchAssistView: View {
    @StateObject private var viewModel: WatchAssistViewModel

    init(viewModel: WatchAssistViewModel) {
        self._viewModel = .init(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            chatList
            micRecording
                .opacity(viewModel.state == .recording ? 1 : 0)
        }
        .animation(.easeInOut, value: viewModel.state)
        .modify {
            if #available(watchOS 10, *) {
                $0.toolbar( viewModel.state == .recording ? .hidden : .visible, for: .navigationBar)
            } else {
                $0
            }
        }
        .modify {
            if #available(watchOS 10, *) {
                $0.toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(destination: WatchAssistSettings()) {
                            Image(systemName: "gear")
                        }
                    }
                }
            } else {
                $0
            }
        }
        #if DEBUG
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                viewModel.chatItems = [
                    .init(content: "How many lights are on?", itemType: .input),
                    .init(content: "3", itemType: .output),
                    .init(content: "Turn them off", itemType: .input),
                    .init(content: "That's done", itemType: .output)
                ]
            }
        }
        #endif
    }

    private var micButton: some View {
        Button {
            viewModel.assist()
        } label: {
            micImage
        }
        .buttonStyle(.plain)
        .ignoresSafeArea()
        .padding(.horizontal, Spaces.two)
        .padding(.top, Spaces.one)
        .padding(.bottom, -Spaces.two)
        .modify {
            if #available(watchOS 10, *) {
                $0.background(.thinMaterial)
            } else {
                $0.background(.black.opacity(0.5))
            }
        }
    }

    private var micImage: some View {
        Image(systemName: "mic")
            .font(.system(size: 22))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.asset(Asset.Colors.haPrimary))
            .clipShape(RoundedRectangle(cornerRadius: 25))
    }

    @ViewBuilder
    private var micRecording: some View {
        Button(action: {
            viewModel.assist()
        }, label: {
            if #available(watchOS 10.0, *) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .symbolEffect(
                        .variableColor.cumulative.dimInactiveLayers.nonReversing,
                        options: viewModel.state == .recording ? .repeating : .nonRepeating,
                        value: viewModel.state
                    )
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.asset(Asset.Colors.haPrimary))
                    .frame(maxHeight: .infinity)
            } else {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 50))
            }
        })
        .buttonStyle(.plain)
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modify {
            if #available(watchOS 10, *) {
                $0.background(.regularMaterial)
            } else {
                $0.background(.black.opacity(0.5))
            }
        }
    }

    private var chatList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(viewModel.chatItems, id: \.id) { item in
                    makeChatBubble(item: item)
                        .id(item.id)
                }
            }
            .frame(maxHeight: .infinity)
            .animation(.easeInOut, value: viewModel.chatItems)
            .onChange(of: viewModel.chatItems) { _ in
                if let lastItem = viewModel.chatItems.last {
                    proxy.scrollTo(lastItem.id, anchor: .bottom)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            micButton
        }
    }

    private func makeChatBubble(item: AssistChatItem) -> some View {
        Text(item.content)
            .listRowBackground(Color.clear)
            .padding(8)
            .padding(.horizontal, 8)
            .background(backgroundForChatItemType(item.itemType))
            .roundedCorner(10, corners: roundedCornersForChatItemType(item.itemType))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: alignmentForChatItemType(item.itemType))
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

#Preview {
    if #available(watchOS 10, *) {
        NavigationStack {
            WatchAssistView.build()
        }
    } else {
        NavigationView {
            WatchAssistView.build()
        }
    }
}
