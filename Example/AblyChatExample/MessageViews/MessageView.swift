import AblyChat
import SwiftUI

struct MessageView: View {
    var item: MessageListItem
    @Binding var isEditing: Bool
    var onDelete: () -> Void
    @State private var isPresentingConfirm = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack {
                Text("\(item.message.clientID):")
                    .foregroundColor(.blue)
                    .bold()
            }
            VStack(alignment: .leading) {
                Text(item.message.text)
                    .foregroundStyle(.black)
                    .background(isEditing ? .orange.opacity(0.12) : .clear)
                if item.message.action == .update {
                    Text("Edited").foregroundStyle(.gray).font(.footnote)
                }
            }
            Spacer()
            if item.isSender {
                MenuButtonView(
                    onEdit: {
                        isEditing = true
                    }, onDelete: {
                        isPresentingConfirm = true
                    }
                )
                .confirmationDialog(
                    "Are you sure?",
                    isPresented: $isPresentingConfirm
                ) {
                    Button("Delete message", role: .destructive) {
                        onDelete()
                        isPresentingConfirm = false
                    }
                } message: {
                    Text("You cannot undo this action")
                }
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
