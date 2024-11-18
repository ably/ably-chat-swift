import Ably

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
        case .messages, .presence, .occupancy:
            // (CHA-M1) Chat messages for a Room are sent on a corresponding realtime channel <roomId>::$chat::$chatMessages. For example, if your room id is my-room then the messages channel will be my-room::$chat::$chatMessages.
            // (CHA-PR1) Presence for a Room is exposed on the realtime channel used for chat messages, in the format <roomId>::$chat::$chatMessages. For example, if your room id is my-room then the presence channel will be my-room::$chat::$chatMessages.
            // (CHA-O1) Occupancy for a room is exposed on the realtime channel used for chat messages, in the format <roomId>::$chat::$chatMessages. For example, if your room id is my-room then the presence channel will be my-room::$chat::$chatMessages.
            "chatMessages"
        case .reactions:
            // (CHA-ER1) Reactions for a Room are sent on a corresponding realtime channel <roomId>::$chat::$reactions. For example, if your room id is my-room then the reactions channel will be my-room::$chat::$reactions.
            "reactions"
        case .typing:
            // We’ll add these, with reference to the relevant spec points, as we implement these features
            fatalError("Don’t know channel name suffix for room feature \(self)")
        }
    }
}

/// Provides all of the channel-related functionality that a room feature (e.g. an implementation of ``Messages``) needs.
///
/// This mishmash exists to give a room feature access to both:
///
/// - a `RealtimeChannelProtocol` object (this is the interface that our features are currently written against, as opposed to, say, `RoomLifecycleContributorChannel`)
/// - the discontinuities emitted by the room lifecycle
internal protocol FeatureChannel: Sendable, EmitsDiscontinuities {
    var channel: RealtimeChannelProtocol { get }
}

internal struct DefaultFeatureChannel: FeatureChannel {
    internal var channel: RealtimeChannelProtocol
    internal var contributor: DefaultRoomLifecycleContributor

    internal func subscribeToDiscontinuities() async -> Subscription<ARTErrorInfo> {
        await contributor.subscribeToDiscontinuities()
    }
}
