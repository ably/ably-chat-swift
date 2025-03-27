import Ably

/// The features offered by a chat room.
internal enum RoomFeature {
    case messages
    case presence
    case typing
    case reactions
    case occupancy
}
