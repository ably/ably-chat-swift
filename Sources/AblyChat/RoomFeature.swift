import Ably

/// The features offered by a chat room.
internal enum RoomFeature: CaseIterable {
    // This list MUST be kept in the same order as the list in CHA-RC2e, in order for the implementation of `areInPrecedenceListOrder` to work.
    case messages
    case presence
    case typing
    case reactions
    case occupancy

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
            // (CHA-T1) Typing Indicators for a Room is exposed on a dedicated Realtime channel. These channels use the format <roomId>::$chat::$typingIndicators. For example, if your room id is my-room then the typing channel will be my-room::$chat::$typingIndicators.
            "typingIndicators"
        }
    }

    /// Returns a `Bool` indicating whether `first` and `second` are in the same order as the list given in CHA-RC2e.
    internal static func areInPrecedenceListOrder(_ first: Self, _ second: Self) -> Bool {
        let allCases = Self.allCases
        let indexOfFirst = allCases.firstIndex(of: first)!
        let indexOfSecond = allCases.firstIndex(of: second)!
        return indexOfFirst < indexOfSecond
    }
}

/// Provides all of the channel-related functionality that a room feature (e.g. an implementation of ``Messages``) needs.
///
/// This mishmash exists to give a room feature access to:
///
/// - a `RealtimeChannelProtocol` object
/// - the discontinuities emitted by the room lifecycle
/// - the presence-readiness wait mechanism supplied by the room lifecycle
internal protocol FeatureChannel: Sendable, EmitsDiscontinuities {
    var channel: any InternalRealtimeChannelProtocol { get }

    /// Waits until we can perform presence operations on the contributors of this room without triggering an implicit attach.
    ///
    /// Implements the checks described by CHA-PR3d, CHA-PR3e, and CHA-PR3h (and similar ones described by other functionality that performs contributor presence operations). Namely:
    ///
    /// - CHA-RL9, which is invoked by CHA-PR3d, CHA-PR10d, CHA-PR6c, CHA-T2c: If the room is in the ATTACHING status, it waits for the next room status change. If the new status is ATTACHED, it returns. Else, it throws an `ARTErrorInfo` derived from ``ChatError/roomTransitionedToInvalidStateForPresenceOperation(cause:)``.
    /// - CHA-PR3e, CHA-PR10e, CHA-PR6d, CHA-T2d: If the room is in the ATTACHED status, it returns immediately.
    /// - CHA-PR3h, CHA-PR10h, CHA-PR6h, CHA-T2g: If the room is in any other status, it throws an `ARTErrorInfo` derived from ``ChatError/presenceOperationRequiresRoomAttach(feature:)``.
    ///
    /// - Parameters:
    ///   - requester: The room feature that wishes to perform a presence operation. This is only used for customising the message of the thrown error.
    func waitToBeAbleToPerformPresenceOperations(requestedByFeature requester: RoomFeature) async throws(InternalError)
}

internal struct DefaultFeatureChannel: FeatureChannel {
    internal var channel: any InternalRealtimeChannelProtocol
    internal var contributor: DefaultRoomLifecycleContributor
    internal var roomLifecycleManager: RoomLifecycleManager

    internal func onDiscontinuity(bufferingPolicy: BufferingPolicy) async -> Subscription<DiscontinuityEvent> {
        await contributor.onDiscontinuity(bufferingPolicy: bufferingPolicy)
    }

    internal func waitToBeAbleToPerformPresenceOperations(requestedByFeature requester: RoomFeature) async throws(InternalError) {
        try await roomLifecycleManager.waitToBeAbleToPerformPresenceOperations(requestedByFeature: requester)
    }
}
