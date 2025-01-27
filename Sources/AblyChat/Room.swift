import Ably

/**
 * Represents a chat room.
 */
public protocol Room: AnyObject, Sendable {
    /**
     * The unique identifier of the room.
     *
     * - Returns: The room identifier.
     */
    var roomID: String { get }

    /**
     * Allows you to send, subscribe-to and query messages in the room.
     *
     * - Returns: The messages instance for the room.
     */
    var messages: any Messages { get }

    /**
     * Allows you to subscribe to presence events in the room.
     *
     * - Note: To access this property if presence is not enabled for the room is a programmer error, and will lead to `fatalError` being called.
     *
     * - Returns: The presence instance for the room.
     */
    var presence: any Presence { get }

    /**
     * Allows you to interact with room-level reactions.
     *
     * - Note: To access this property if presence is not enabled for the room is a programmer error, and will lead to `fatalError` being called.
     *
     * - Returns: The room reactions instance for the room.
     */
    var reactions: any RoomReactions { get }

    /**
     * Allows you to interact with typing events in the room.
     *
     * - Note: To access this property if presence is not enabled for the room is a programmer error, and will lead to `fatalError` being called.
     *
     * - Returns: The typing instance for the room.
     */
    var typing: any Typing { get }

    /**
     * Allows you to interact with occupancy metrics for the room.
     *
     * - Note: To access this property if presence is not enabled for the room is a programmer error, and will lead to `fatalError` being called.
     *
     * - Returns: The occupancy instance for the room.
     */
    var occupancy: any Occupancy { get }

    /**
     * The current status of the room.
     *
     * - Returns: The current room status.
     */
    var status: RoomStatus { get async }

    /**
     * Subscribes a given listener to the room status changes.
     *
     * - Parameters:
     *   - bufferingPolicy: The ``BufferingPolicy`` for the created subscription.
     *
     * - Returns: A subscription `AsyncSequence` that can be used to iterate through ``RoomStatusChange`` events.
     */
    func onStatusChange(bufferingPolicy: BufferingPolicy) async -> Subscription<RoomStatusChange>

    /// Same as calling ``onStatusChange(bufferingPolicy:)`` with ``BufferingPolicy/unbounded``.
    ///
    /// The `Room` protocol provides a default implementation of this method.
    func onStatusChange() async -> Subscription<RoomStatusChange>

    /**
     * Attaches to the room to receive events in realtime.
     *
     * If a room fails to attach, it will enter either the ``RoomStatus/suspended(error:)`` or ``RoomStatus/failed(error:)`` state.
     *
     * If the room enters the failed state, then it will not automatically retry attaching and intervention is required.
     *
     * If the room enters the suspended state, then the call to attach will throw `ARTErrorInfo` with the cause of the suspension. However,
     * the room will automatically retry attaching after a delay.
     *
     * - Throws: An `ARTErrorInfo`.
     */
    func attach() async throws

    /**
     * Detaches from the room to stop receiving events in realtime.
     *
     * - Throws: An `ARTErrorInfo`.
     */
    func detach() async throws

    /**
     * Returns the room options.
     *
     * - Returns: A copy of the options used to create the room.
     */
    var options: RoomOptions { get }
}

public extension Room {
    func onStatusChange() async -> Subscription<RoomStatusChange> {
        await onStatusChange(bufferingPolicy: .unbounded)
    }
}

/// A ``Room`` that exposes additional functionality for use within the SDK.
internal protocol InternalRoom: Room {
    func release() async
}

/**
 * Represents a change in the status of the room.
 */
public struct RoomStatusChange: Sendable, Equatable {
    /**
     * The new status of the room.
     */
    public var current: RoomStatus

    /**
     * The previous status of the room.
     */
    public var previous: RoomStatus

    public init(current: RoomStatus, previous: RoomStatus) {
        self.current = current
        self.previous = previous
    }
}

internal protocol RoomFactory: Sendable {
    associatedtype Room: AblyChat.InternalRoom

    func createRoom(realtime: RealtimeClient, chatAPI: ChatAPI, roomID: String, options: RoomOptions, logger: InternalLogger) async throws -> Room
}

internal final class DefaultRoomFactory: Sendable, RoomFactory {
    private let lifecycleManagerFactory = DefaultRoomLifecycleManagerFactory()

    internal func createRoom(realtime: RealtimeClient, chatAPI: ChatAPI, roomID: String, options: RoomOptions, logger: InternalLogger) async throws -> DefaultRoom<DefaultRoomLifecycleManagerFactory> {
        try await DefaultRoom(
            realtime: realtime,
            chatAPI: chatAPI,
            roomID: roomID,
            options: options,
            logger: logger,
            lifecycleManagerFactory: lifecycleManagerFactory
        )
    }
}

internal actor DefaultRoom<LifecycleManagerFactory: RoomLifecycleManagerFactory>: InternalRoom where LifecycleManagerFactory.Contributor == DefaultRoomLifecycleContributor {
    internal nonisolated let roomID: String
    internal nonisolated let options: RoomOptions
    private let chatAPI: ChatAPI

    public nonisolated let messages: any Messages
    private let _reactions: (any RoomReactions)?
    private let _presence: (any Presence)?
    private let _occupancy: (any Occupancy)?
    private let _typing: (any Typing)?

    // Exposed for testing.
    private nonisolated let realtime: RealtimeClient

    private let lifecycleManager: any RoomLifecycleManager
    private let channels: [any RealtimeChannelProtocol]

    private let logger: InternalLogger

    private enum RoomFeatureWithOptions {
        case messages
        case presence(PresenceOptions)
        case typing(TypingOptions)
        case reactions(RoomReactionsOptions)
        case occupancy(OccupancyOptions)

        var toRoomFeature: RoomFeature {
            switch self {
            case .messages:
                .messages
            case .presence:
                .presence
            case .typing:
                .typing
            case .reactions:
                .reactions
            case .occupancy:
                .occupancy
            }
        }

        static func fromRoomOptions(_ roomOptions: RoomOptions) -> [Self] {
            var result: [Self] = [.messages]

            if let presenceOptions = roomOptions.presence {
                result.append(.presence(presenceOptions))
            }

            if let typingOptions = roomOptions.typing {
                result.append(.typing(typingOptions))
            }

            if let reactionsOptions = roomOptions.reactions {
                result.append(.reactions(reactionsOptions))
            }

            if let occupancyOptions = roomOptions.occupancy {
                result.append(.occupancy(occupancyOptions))
            }

            return result
        }
    }

    internal init(realtime: RealtimeClient, chatAPI: ChatAPI, roomID: String, options: RoomOptions, logger: InternalLogger, lifecycleManagerFactory: LifecycleManagerFactory) async throws {
        self.realtime = realtime
        self.roomID = roomID
        self.options = options
        self.logger = logger
        self.chatAPI = chatAPI

        guard let clientId = realtime.clientId else {
            throw ARTErrorInfo.create(withCode: 40000, message: "Ensure your Realtime instance is initialized with a clientId.")
        }

        let featuresWithOptions = RoomFeatureWithOptions.fromRoomOptions(options)

        let featureChannelPartialDependencies = Self.createFeatureChannelPartialDependencies(roomID: roomID, featuresWithOptions: featuresWithOptions, realtime: realtime)
        channels = featureChannelPartialDependencies.map(\.featureChannelPartialDependencies.channel)
        let contributors = featureChannelPartialDependencies.map(\.featureChannelPartialDependencies.contributor)

        lifecycleManager = await lifecycleManagerFactory.createManager(
            contributors: contributors,
            logger: logger
        )

        let featureChannels = Self.createFeatureChannels(partialDependencies: featureChannelPartialDependencies, lifecycleManager: lifecycleManager)

        messages = await DefaultMessages(
            featureChannel: featureChannels[.messages]!,
            chatAPI: chatAPI,
            roomID: roomID,
            clientID: clientId,
            logger: logger
        )

        _reactions = if let featureChannel = featureChannels[.reactions] {
            await DefaultRoomReactions(
                featureChannel: featureChannel,
                clientID: clientId,
                roomID: roomID,
                logger: logger
            )
        } else {
            nil
        }

        _presence = if let featureChannel = featureChannels[.presence] {
            await DefaultPresence(
                featureChannel: featureChannel,
                roomID: roomID,
                clientID: clientId,
                logger: logger
            )
        } else {
            nil
        }

        _occupancy = if let featureChannel = featureChannels[.occupancy] {
            DefaultOccupancy(
                featureChannel: featureChannel,
                chatAPI: chatAPI,
                roomID: roomID,
                logger: logger
            )
        } else {
            nil
        }

        _typing = if let featureChannel = featureChannels[.typing] {
            DefaultTyping(
                featureChannel: featureChannel,
                roomID: roomID,
                clientID: clientId,
                logger: logger,
                timeout: options.typing?.timeout ?? 5
            )
        } else {
            nil
        }
    }

    private struct FeatureChannelPartialDependencies {
        internal var channel: any RealtimeChannelProtocol
        internal var contributor: DefaultRoomLifecycleContributor
    }

    /// Each feature in `featuresWithOptions` is guaranteed to appear in the `features` member of precisely one of the returned array’s values.
    private static func createFeatureChannelPartialDependencies(roomID: String, featuresWithOptions: [RoomFeatureWithOptions], realtime: RealtimeClient) -> [(features: [RoomFeature], featureChannelPartialDependencies: FeatureChannelPartialDependencies)] {
        // CHA-RC3a

        // Multiple features can share a realtime channel. We fetch each realtime channel exactly once, merging the channel options for the various features that use this channel.

        // CHA-RL5a1: This spec point requires us to implement a special behaviour to handle the fact that multiple contributors can share a channel. I have decided, instead, to make it so that each channel has precisely one lifecycle contributor. I think this is a simpler, functionally equivalent approach and have suggested it in https://github.com/ably/specification/issues/240.

        let featuresGroupedByChannelName = Dictionary(grouping: featuresWithOptions) { $0.toRoomFeature.channelNameForRoomID(roomID) }

        let unorderedResult = featuresGroupedByChannelName.map { channelName, features in
            var channelOptions = RealtimeChannelOptions()

            // channel setup for presence and occupancy
            for feature in features {
                if case /* let */ .presence /* (presenceOptions) */ = feature {
                    // TODO: Restore this code once we understand weird Realtime behaviour and spec points (https://github.com/ably-labs/ably-chat-swift/issues/133)
                    /*
                     if presenceOptions.enter {
                         channelOptions.modes.insert(.presence)
                     }

                     if presenceOptions.subscribe {
                         channelOptions.modes.insert(.presenceSubscribe)
                     }
                     */
                } else if case .occupancy = feature {
                    var params: [String: String] = channelOptions.params ?? [:]
                    params["occupancy"] = "metrics"
                    channelOptions.params = params
                }
            }

            let channel = realtime.getChannel(channelName, opts: channelOptions)

            // Give the contributor the first of the enabled features that correspond to this channel, using CHA-RC2e ordering. This will determine which feature is used for atttachment and detachment errors.
            let contributorFeature = features.map(\.toRoomFeature).sorted { RoomFeature.areInPrecedenceListOrder($0, $1) }[0]

            let contributor = DefaultRoomLifecycleContributor(channel: .init(underlyingChannel: channel), feature: contributorFeature)
            let featureChannelPartialDependencies = FeatureChannelPartialDependencies(channel: channel, contributor: contributor)

            return (features.map(\.toRoomFeature), featureChannelPartialDependencies)
        }

        // Sort the result in CHA-RC2e order
        return unorderedResult.sorted { RoomFeature.areInPrecedenceListOrder($0.1.contributor.feature, $1.1.contributor.feature) }
    }

    private static func createFeatureChannels(partialDependencies: [(features: [RoomFeature], featureChannelPartialDependencies: FeatureChannelPartialDependencies)], lifecycleManager: RoomLifecycleManager) -> [RoomFeature: DefaultFeatureChannel] {
        let pairsOfFeatureAndPartialDependencies = partialDependencies.flatMap { features, partialDependencies in
            features.map { (feature: $0, partialDependencies: partialDependencies) }
        }

        return Dictionary(uniqueKeysWithValues: pairsOfFeatureAndPartialDependencies).mapValues { partialDependencies in
            .init(
                channel: partialDependencies.channel,
                contributor: partialDependencies.contributor,
                roomLifecycleManager: lifecycleManager
            )
        }
    }

    public nonisolated var presence: any Presence {
        guard let _presence else {
            fatalError("Presence is not enabled for this room")
        }
        return _presence
    }

    public nonisolated var reactions: any RoomReactions {
        guard let _reactions else {
            fatalError("Reactions are not enabled for this room")
        }
        return _reactions
    }

    public nonisolated var typing: any Typing {
        guard let _typing else {
            fatalError("Typing is not enabled for this room")
        }
        return _typing
    }

    public nonisolated var occupancy: any Occupancy {
        guard let _occupancy else {
            fatalError("Occupancy is not enabled for this room")
        }
        return _occupancy
    }

    public func attach() async throws {
        try await lifecycleManager.performAttachOperation()
    }

    public func detach() async throws {
        try await lifecycleManager.performDetachOperation()
    }

    internal func release() async {
        await lifecycleManager.performReleaseOperation()

        // CHA-RL3h
        for channel in channels {
            realtime.channels.release(channel.name)
        }
    }

    // MARK: - Room status

    internal func onStatusChange(bufferingPolicy: BufferingPolicy) async -> Subscription<RoomStatusChange> {
        await lifecycleManager.onRoomStatusChange(bufferingPolicy: bufferingPolicy)
    }

    internal var status: RoomStatus {
        get async {
            await lifecycleManager.roomStatus
        }
    }
}
