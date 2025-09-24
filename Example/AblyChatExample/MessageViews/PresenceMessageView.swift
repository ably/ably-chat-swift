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
        let status = item.presence.member.data?["status"]?.stringValue
        let clientPresenceChangeMessage = "\(item.presence.member.clientID) \(item.presence.type)"
        let presenceMessage = status != nil ? "\(clientPresenceChangeMessage) with status: \(status!)" : clientPresenceChangeMessage
        return presenceMessage
    }
}

struct PresenceListItem {
    var presence: PresenceEvent
}
