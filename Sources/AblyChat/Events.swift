internal enum MessageEvent: String {
    case created = "message.created"
}

internal enum RoomReactionEvents: String {
    case reaction = "roomReaction"
}

internal enum OccupancyEvents: String {
    case meta = "[meta]occupancy"
}
