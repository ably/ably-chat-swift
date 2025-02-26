import AblyChat
import SwiftUI

struct PresenceMessageView: View {
    var item: PresenceListItem

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack {
                Text("System:")
                    .foregroundColor(.blue)
                    .bold()
                Spacer()
            }
            VStack {
                Text(generatePresenceMessage())
            }
        }
        #if !os(tvOS)
        .listRowSeparator(.hidden)
        #endif
    }

    func generatePresenceMessage() -> String {
        let status = item.presence.data?.objectValue?["status"]?.stringValue
        let clientPresenceChangeMessage = "\(item.presence.clientID) \(item.presence.action.displayedText)"
        let presenceMessage = status != nil ? "\(clientPresenceChangeMessage) with status: \(status!)" : clientPresenceChangeMessage
        return presenceMessage
    }
}

struct PresenceListItem {
    var presence: PresenceEvent
}
