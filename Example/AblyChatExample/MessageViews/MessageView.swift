import AblyChat
import SwiftUI

struct MessageView: View {
    let currentClientID: String
    var item: MessageListItem
    @Binding var isEditing: Bool
    var onDeleteMessage: () -> Void
    let onAddReaction: (String) -> Void
    let onDeleteReaction: (String) -> Void

    @State private var isDeleteConfirmationPresented = false
    @State private var showAllReactionsSheet = false
    @State private var showReactionPicker = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack {
                Text("\(item.message.clientID):")
                    .foregroundColor(.blue)
                    .bold()
            }
            VStack(alignment: .leading) {
                Text(item.message.text)
                    .background(isEditing ? .orange.opacity(0.12) : .clear)
                    .onLongPressGesture {
                        showReactionPicker = true
                    }
                    .padding(left: 2)
                if item.message.action == .messageUpdate {
                    Text("Edited")
                        .foregroundStyle(.gray)
                        .font(.footnote)
                }
                MessageReactionSummaryView(
                    summary: item.message.reactions,
                    currentClientID: currentClientID,
                    onPickReaction: {
                        showReactionPicker = true
                    },
                    onAddReaction: onAddReaction,
                    onDeleteReaction: onDeleteReaction,
                )
                .padding(left: 2)
            }
            Spacer()
            if item.isSender {
                MenuButtonView(
                    onEdit: {
                        isEditing = true
                    }, onDelete: {
                        isDeleteConfirmationPresented = true
                    },
                )
                .confirmationDialog(
                    "Are you sure?",
                    isPresented: $isDeleteConfirmationPresented,
                ) {
                    Button("Delete message", role: .destructive) {
                        onDeleteMessage()
                        isDeleteConfirmationPresented = false
                    }
                } message: {
                    Text("You cannot undo this action")
                }
            }
        }
        .sheet(isPresented: $showReactionPicker) {
            MessageReactionsPicker { emoji in
                showReactionPicker = false
                onAddReaction(emoji)
            }
        }
        #if !os(tvOS)
        .listRowSeparator(.hidden)
        #endif
    }
}

struct MessageListItem {
    var message: Message
    var isSender: Bool = false
}
