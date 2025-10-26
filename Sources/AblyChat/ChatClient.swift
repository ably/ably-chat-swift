import Ably

// This disable of attributes can be removed once missing_docs fixed here
// swiftlint:disable attributes
@MainActor
// swiftlint:disable:next missing_docs
public protocol ChatClientProtocol: AnyObject, Sendable {
    // swiftlint:enable attributes

    // swiftlint:disable:next missing_docs
    associatedtype Realtime
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
     * Returns the underlying Ably Realtime client.
     *
     * - Returns: The Ably Realtime client.
     */
    var realtime: Realtime { get }

    /**
     * Returns the resolved client options for the client, including any defaults that have been set.
     *
     * - Returns: The client options.
     */
    var clientOptions: ChatClientOptions { get }
}

@MainActor
internal protocol InternalRealtimeClientFactory {
    associatedtype Underlying: RealtimeClientProtocol
    associatedtype Output: InternalRealtimeClientProtocol
    func createInternalRealtimeClient(_ ablyCocoaRealtime: Underlying) -> Output
}

internal final class DefaultInternalRealtimeClientFactory<Underlying: ProxyRealtimeClientProtocol>: InternalRealtimeClientFactory {
    internal func createInternalRealtimeClient(_ ablyCocoaRealtime: Underlying) -> InternalRealtimeClientAdapter<Underlying> {
        .init(underlying: ablyCocoaRealtime)
    }
}

/**
 * This is the core client for Ably chat. It provides access to chat rooms.
 */
public class ChatClient: ChatClientProtocol {
    /**
     * Returns the underlying Ably Realtime client.
     *
     * - Returns: The Ably Realtime client.
     */
    public let realtime: ARTRealtime
    
    /**
     * Returns the resolved client options for the client, including any defaults that have been set.
     *
     * - Returns: The client options.
     */
    public let clientOptions: ChatClientOptions
    private let _rooms: DefaultRooms<DefaultRoomFactory<InternalRealtimeClientAdapter<ARTWrapperSDKProxyRealtime>>>
    
    /**
     * Returns the rooms object, which provides access to chat rooms.
     *
     * - Returns: The rooms object.
     */
    public var rooms: some Rooms<ARTRealtimeChannel> {
        _rooms
    }

    private let logger: any InternalLogger

    // (CHA-CS1) Every chat client has a status, which describes the current status of the connection.
    // (CHA-CS4) The chat client must allow its connection status to be observed by clients.
    private let _connection: DefaultConnection
    
    /**
     * Returns the underlying connection to Ably, which can be used to monitor the client's
     * connection to Ably servers.
     *
     * - Returns: The connection object.
     */
    public var connection: some Connection {
        _connection
    }

    /**
     * Constructor for Chat
     *
     * - Important: The Ably Realtime client must have a clientId set. This can be done by configuring
     * token-based authentication that returns a token with a clientId, or by setting
     * the clientId directly in the Realtime client options.
     *
     * - Parameters:
     *   - realtime: The Ably Realtime client. Its `dispatchQueue` option must be the main queue (this is its default behaviour).
     *   - clientOptions: The client options.
     */
    public convenience init(realtime: ARTRealtime, clientOptions: ChatClientOptions? = nil) {
        self.init(
            realtime: realtime,
            clientOptions: clientOptions,
            internalRealtimeClientFactory: DefaultInternalRealtimeClientFactory<ARTWrapperSDKProxyRealtime>(),
        )
    }

    internal init<RealtimeClientFactory: InternalRealtimeClientFactory>(
        realtime suppliedRealtime: ARTRealtime,
        clientOptions: ChatClientOptions?,
        internalRealtimeClientFactory: RealtimeClientFactory,
    ) where RealtimeClientFactory.Underlying == ARTWrapperSDKProxyRealtime, RealtimeClientFactory.Output == InternalRealtimeClientAdapter<ARTWrapperSDKProxyRealtime> {
        self.realtime = suppliedRealtime
        self.clientOptions = clientOptions ?? .init()

        // CHA-IN1a
        let realtime = suppliedRealtime.createWrapperSDKProxy(
            with: .init(agents: ClientInformation.agents),
        )
        let internalRealtime = internalRealtimeClientFactory.createInternalRealtimeClient(realtime)

        logger = DefaultInternalLogger(logHandler: self.clientOptions.logHandler, logLevel: self.clientOptions.logLevel)
        let roomFactory = DefaultRoomFactory<InternalRealtimeClientAdapter<ARTWrapperSDKProxyRealtime>>()
        _rooms = DefaultRooms(realtime: internalRealtime, logger: logger, roomFactory: roomFactory)
        _connection = DefaultConnection(realtime: internalRealtime)
    }

    /**
     * Returns the clientID of the current client, if known.
     *
     * - Important: When using an Ably key for authentication, this value is determined immediately. If using a token,
     * the clientID is not known until the client has successfully connected to and authenticated with
     * the server. Use the `chatClient.connection.status` to check the connection status.
     *
     * - Returns: The clientID, or `nil` if unknown.
     */
    public var clientID: String? {
        realtime.clientId
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

    /**
     * Creates a new instance of ``ChatClientOptions``.
     *
     * - Parameters:
     *   - logHandler: A custom log handler for logging messages from the client.
     *   - logLevel: The minimum log level at which messages will be logged.
     */
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
