/// The features offered by a chat room.
internal enum RoomFeature {
    case messages
    case presence
    case reactions
    case occupancy
    case typing

    internal func channelNameForRoomID(_ roomID: String) -> String {
        "\(roomID)::$chat::$\(channelNameSuffix)"
    }

    private var channelNameSuffix: String {
        switch self {
        case .messages:
            // (CHA-M1) Chat messages for a Room are sent on a corresponding realtime channel <roomId>::$chat::$chatMessages. For example, if your room id is my-room then the messages channel will be my-room::$chat::$chatMessages.
            "chatMessages"
        case .typing, .reactions, .presence, .occupancy:
            // We’ll add these, with reference to the relevant spec points, as we implement these features
            fatalError("Don’t know channel name suffix for room feature \(self)")
        }
    }
}
