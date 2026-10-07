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
        .modify { view in
            let color = backgroundForChatItemType(item.itemType)
            let corners = roundedCornersForChatItemType(item.itemType)
            if #available(watchOS 26.0, *) {
                view.glassEffect(
                    .regular.tint(color),
                    in: RoundedCorner(radius: DesignSystem.CornerRadius.oneAndHalf, corners: corners)
                )
            } else {
                view
                    .background(color)
                    .roundedCorner(6, corners: corners)
            }
        }
        .foregroundColor(foregroundForChatItemType(item.itemType))
        .tint(tintForChatItemType(item.itemType))
        .frame(maxWidth: .infinity, alignment: alignmentForChatItemType(item.itemType))
        .listRowBackground(Color.clear)
        .id(item.id)
    }

    private func backgroundForChatItemType(_ itemType: AssistChatItem.ItemType) -> Color {
        switch itemType {
        case .input, .pending:
            .haPrimary
        case .output, .typing:
            .secondaryBackground
        case .error:
            .red.opacity(0.3)
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

#Preview {
    ScrollView {
        LazyVStack(spacing: DesignSystem.Spaces.one) {
            ChatBubbleView(item: .init(content: "Turn on the kitchen lights", itemType: .input))
            ChatBubbleView(item: .init(content: "Done, 3 lights are now on.", itemType: .output))
            ChatBubbleView(item: .init(content: "Sending…", itemType: .pending))
            ChatBubbleView(item: .init(content: "", itemType: .typing))
            ChatBubbleView(item: .init(content: "Something went wrong. Please try again.", itemType: .error))
            ChatBubbleView(item: .init(content: "Listening…", itemType: .info))
        }
        .padding()
    }
    .background(
        LinearGradient(
            colors: [.black, Color.haPrimary.opacity(0.4), .black],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    )
}
