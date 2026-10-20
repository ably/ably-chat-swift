import AblyPubSubDevice

// This disable of attributes can be removed once missing_docs fixed here
// swiftlint:disable attributes
@MainActor
// swiftlint:disable:next missing_docs
public protocol ChatClientProtocol: AnyObject, Sendable {
    // swiftlint:enable attributes

    // swiftlint:disable:next missing_docs
    associatedtype PubSubClient
    // swiftlint:disable:next missing_docs
    associatedtype Connection: AblyChat.Connection
    // swiftlint:disable:next missing_docs
    associatedtype Rooms: AblyChat.Rooms

    /**
     * Returns the rooms object, which provides access to chat rooms.
     *
     * - Returns: The rooms object.
     */
    var rooms: Rooms { get }

    /**
     * Returns the underlying connection to Ably, which can be used to monitor the clients
     * connection to Ably servers.
     *
     * - Returns: The connection object.
     */
    var connection: Connection { get }

    /**
     * Returns the clientID of the current client, if known.
     *
     * - Important: When using an Ably key for authentication, this value is determined immediately. If using a token,
     * the clientID is not known until the client has successfully connected to and authenticated with
     * the server. Use the `chatClient.connection.status` to check the connection status.

     * - Returns: The clientID, or `nil` if unknown.
     */
    var clientID: String? { get }

    /**
     * Returns the underlying Ably Pub/Sub client.
     *
     * - Returns: The Ably Pub/Sub client.
     */
    var pubSubClient: PubSubClient { get }

    /**
     * Returns the resolved client options for the client, including any defaults that have been set.
     *
     * - Returns: The client options.
     */
    var clientOptions: ChatClientOptions { get }
}

@MainActor
internal protocol InternalPubSubClientFactory {
    associatedtype Underlying: PubSubClientProtocol
    associatedtype Output: InternalPubSubClientProtocol
    func createInternalPubSubClient(_ ablyCocoaPubSubClient: Underlying) -> Output
}

internal final class DefaultInternalPubSubClientFactory<Underlying: ProxyPubSubClientProtocol>: InternalPubSubClientFactory {
    internal func createInternalPubSubClient(_ ablyCocoaPubSubClient: Underlying) -> InternalPubSubClientAdapter<Underlying> {
        .init(underlying: ablyCocoaPubSubClient)
    }
}

/**
 * Creates a chat client.
 *
 * - Parameters:
 *   - pubSubClient: The Ably Pub/Sub client. Its `dispatchQueue` option must be the main queue (this is its default behaviour).
 *   - clientOptions: The client options.
 *
 * - Returns: A chat client that uses `pubSubClient` to communicate with Ably.
 */
@MainActor
public func createChatClient(pubSubClient: PubSubClient, clientOptions: ChatClientOptions? = nil) -> ChatClient {
    ChatClient(
        pubSubClient: pubSubClient,
        clientOptions: clientOptions,
        internalPubSubClientFactory: DefaultInternalPubSubClientFactory<WrapperSDKProxyRealtime>(),
    )
}

/**
 * This is the core client for Ably chat. It provides access to chat rooms.
 *
 * Use ``createChatClient(pubSubClient:clientOptions:)`` to create one.
 */
public class ChatClient: ChatClientProtocol {
    // swiftlint:disable:next missing_docs
    public let pubSubClient: AblyPubSubDevice.PubSubClient
    // swiftlint:disable:next missing_docs
    public let clientOptions: ChatClientOptions
    private let _rooms: DefaultRooms<DefaultRoomFactory<InternalPubSubClientAdapter<WrapperSDKProxyRealtime>>>
    // swiftlint:disable:next missing_docs
    public var rooms: some Rooms<RealtimeChannel> {
        _rooms
    }

    private let logger: any InternalLogger

    // (CHA-CS1) Every chat client has a status, which describes the current status of the connection.
    // (CHA-CS4) The chat client must allow its connection status to be observed by clients.
    private let _connection: DefaultConnection
    // swiftlint:disable:next missing_docs
    public var connection: some Connection {
        _connection
    }

    internal init<PubSubClientFactory: InternalPubSubClientFactory>(
        pubSubClient suppliedPubSubClient: AblyPubSubDevice.PubSubClient,
        clientOptions: ChatClientOptions?,
        internalPubSubClientFactory: PubSubClientFactory,
    ) where PubSubClientFactory.Underlying == WrapperSDKProxyRealtime, PubSubClientFactory.Output == InternalPubSubClientAdapter<WrapperSDKProxyRealtime> {
        self.pubSubClient = suppliedPubSubClient
        self.clientOptions = clientOptions ?? .init()

        // CHA-IN1a
        let pubSubClient = suppliedPubSubClient.createWrapperSDKProxy(
            with: .init(agents: ClientInformation.agents),
        )
        let internalPubSubClient = internalPubSubClientFactory.createInternalPubSubClient(pubSubClient)

        logger = DefaultInternalLogger(logHandler: self.clientOptions.logHandler, logLevel: self.clientOptions.logLevel)
        let roomFactory = DefaultRoomFactory<InternalPubSubClientAdapter<WrapperSDKProxyRealtime>>()
        _rooms = DefaultRooms(pubSubClient: internalPubSubClient, logger: logger, roomFactory: roomFactory)
        _connection = DefaultConnection(pubSubClient: internalPubSubClient)
    }

    // swiftlint:disable:next missing_docs
    public var clientID: String? {
        pubSubClient.clientId
    }
}

/**
 * Configuration options for the chat client.
 */
public struct ChatClientOptions: Sendable {
    /**
     * A custom log handler that will be used to log messages from the client.
     *
     * By default, the client will log messages to the console.
     */
    public var logHandler: LogHandler?

    /**
     * The minimum log level at which messages will be logged.
     *
     * By default, ``LogLevel/error`` will be used. Set this property to `nil` to disable logging.
     */
    public var logLevel: LogLevel? = .error

    // swiftlint:disable:next missing_docs
    public init(logHandler: LogHandler? = nil, logLevel: LogLevel? = .error) {
        self.logHandler = logHandler
        self.logLevel = logLevel
    }

    /// Used for comparing these instances in tests without having to make this Equatable, which I'm not yet sure makes sense (we'll decide in https://github.com/ably-labs/ably-chat-swift/issues/10)
    ///
    /// - Warning: Both set of options must have a `nil` `logHandler` (we can't compare `LogHandler` for equality because its underlying logger is not class-bound).
    internal func isEqualForTestPurposes(_ other: ChatClientOptions) -> Bool {
        precondition(logHandler == nil && other.logHandler == nil)

        return logLevel == other.logLevel
    }
}
