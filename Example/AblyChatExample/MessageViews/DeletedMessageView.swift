import SwiftUI

struct DeletedMessageView: View {
    var item: MessageListItem

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack {
                Text("\(item.message.clientID):")
                    .foregroundColor(.blue)
                    .bold()
            }
            VStack {
                Text("This message was deleted.")
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        #if !os(tvOS)
        .listRowSeparator(.hidden)
        #endif
    }
}
