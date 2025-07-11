import Shared
import SwiftUI

struct ChatBubbleView: View {
    let item: AssistChatItem

    var body: some View {
        Group {
            if item.itemType == .typing {
                AssistTypingIndicator()
                    .padding(.vertical, DesignSystem.Spaces.half)
            } else {
                Text(item.markdown)
            }
        }
        .padding(4)
        .padding(.horizontal, 4)
        .background(backgroundForChatItemType(item.itemType))
        .roundedCorner(6, corners: roundedCornersForChatItemType(item.itemType))
        .foregroundColor(foregroundForChatItemType(item.itemType))
        .tint(tintForChatItemType(item.itemType))
        .frame(maxWidth: .infinity, alignment: alignmentForChatItemType(item.itemType))
        .listRowBackground(Color.clear)
        .id(item.id)
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
            .gray.opacity(0.5)
        }
    }

    private func foregroundForChatItemType(_ itemType: AssistChatItem.ItemType) -> Color {
        switch itemType {
        case .input, .error:
            .white
        case .info:
            .secondary
        default:
            .black
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

#Preview {
    LazyVStack(spacing: 8) {
        ChatBubbleView(item: .init(content: "Hello world", itemType: .input))
            .background(.red)
        ChatBubbleView(item: .init(content: "Hello world", itemType: .output))
        ChatBubbleView(item: .init(content: "Hello world", itemType: .info))
        ChatBubbleView(item: .init(content: "Hello world", itemType: .input))
        ChatBubbleView(item: .init(content: "Hello world", itemType: .output))
    }
    .background(.green)
}
