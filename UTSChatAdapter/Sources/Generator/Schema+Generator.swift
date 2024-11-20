import Foundation

private let altTypesMap = [
    "void": "Void",
    "PresenceData": "PresenceDataWrapper",
    "MessageSubscriptionResponse": "MessageSubscription",
    "OnConnectionStatusChangeResponse": "OnConnectionStatusChange",
    "OccupancySubscriptionResponse": "OccupancySubscription",
    "RoomReactionsSubscriptionResponse": "RoomReactionsSubscription",
    "OnDiscontinuitySubscriptionResponse": "OnDiscontinuitySubscription",
    "OnRoomStatusChangeResponse": "OnRoomStatusChange",
    "TypingSubscriptionResponse": "TypingSubscription",
    "PresenceSubscriptionResponse": "PresenceSubscription",
    "MessageEventPayload": "Message",
    "PaginatedResult": "PaginatedResultMessage",
]

private let jsonPrimitiveTypesMap = [
    "string": "\(String.self)",
    "boolean": "\(Bool.self)",
    "number": "\(Int.self)",
]

private let altMethodsMap = [
    "onDiscontinuity": "subscribeToDiscontinuities",
    "subscribe_listener": "subscribeAll",
]

func isJsonPrimitiveType(_ typeName: String) -> Bool {
    jsonPrimitiveTypesMap.keys.contains([typeName])
}

func altTypeName(_ typeName: String) -> String {
    (altTypesMap[typeName] ?? jsonPrimitiveTypesMap[typeName]) ?? typeName
}

func altMethodName(_ methodName: String) -> String {
    altMethodsMap[methodName] ?? methodName
}

extension String {
    func bigD() -> String {
        replacingOccurrences(of: "Id", with: "ID")
    }
}

extension Schema {
    // These paths were not yet implemented in SDK or require custom implementation:
    static let skipPaths = [
        "ChatClient", // custom constructor with realtime instance
        "ChatClient#logger", // not exposed
        "RoomStatus#error", // not available directly (via lifecycle object)
        "Message#createdAt", // optional
        "Presence.subscribe_eventsAndListener", // impossible to infer param type from `string`
        "Rooms.get", // custom getter (by "roomId", not with `generateId()`)
        "ChatClient.addReactAgent", // ?

        // Not implemented:

        "Presence#channel",

        "Messages.unsubscribeAll",
        "Presence.unsubscribeAll",
        "Occupancy.unsubscribeAll",
        "RoomReactions.unsubscribeAll",
        "Typing.unsubscribeAll",

        "TypingSubscriptionResponse.unsubscribe",
        "MessageSubscriptionResponse.unsubscribe",
        "OccupancySubscriptionResponse.unsubscribe",
        "PresenceSubscriptionResponse.unsubscribe",
        "PresenceSubscriptionResponse.unsubscribe",
        "RoomReactionsSubscriptionResponse.unsubscribe",

        "OnConnectionStatusChangeResponse.off",
        "OnDiscontinuitySubscriptionResponse.off",
        "OnRoomStatusChangeResponse.off",

        "ConnectionStatus.offAll",
        "RoomStatus.offAll",

        "Logger.error",
        "Logger.trace",
        "Logger.info",
        "Logger.debug",
        "Logger.warn",

        // Removed/changed but not reflected in schema file:

        "ConnectionStatus#current",
        "ConnectionStatus.onChange",
        "RoomStatus#current",
        "RoomStatus.onChange",
        "ConnectionStatus#error",
    ]

    // These paths have dummy implementation in the SDK and will not be called due to tilda prefix (once implemented - remove "~"):
    static let noCallPaths = [
        "ChatClient#connection",
        "Connection#status",
        "ConnectionStatus.onChange",
        "Rooms.release",
        "Room#occupancy",
        "Occupancy.get",
        "Occupancy#channel",
        "Occupancy.subscribe",
        "Occupancy.onDiscontinuity",
        "Room#presence",
        "Presence.enter",
        "Presence.leave",
        "Presence.isUserPresent",
        "Presence.update",
        "Presence.subscribe_listener",
        "Presence.onDiscontinuity",
        "Room#typing",
        "Typing.subscribe",
        "Typing.onDiscontinuity",
        "Typing#channel",
        "Typing.get",
        "Typing.start",
        "Typing.stop",
        "Room#reactions",
        "RoomReactions.subscribe",
        "RoomReactions#channel",
        "RoomReactions.send",
        "RoomReactions.onDiscontinuity",
        "Messages.onDiscontinuity",
    ]
}
