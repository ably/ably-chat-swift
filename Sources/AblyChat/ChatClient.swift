import Ably

/// Protocol defining the interface for an Ably Chat client instance.
@MainActor
public protocol ChatClientProtocol: AnyObject, Sendable {
    /// The underlying Ably Realtime client type.
    associatedtype Realtime
    /// The connection type for monitoring client connectivity.
    associatedtype Connection: AblyChat.Connection
    /// The rooms manager type for creating and managing chat rooms.
    associatedtype Rooms: AblyChat.Rooms

    /**
     * Provides access to the rooms instance for creating and managing chat rooms.
     *
     * - Returns: The Rooms instance for managing chat rooms
     *
     * ## Example
     *
     * ```swift
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * // Get a room with default options
     * let room = try await chatClient.rooms.get("general-chat")
     *
     * // Get a room with custom options (merges with defaults)
     * let configuredRoom = try await chatClient.rooms.get("team-chat", options: RoomOptions(
     *     typing: TypingOptions(heartbeatThrottle: 1) // in seconds
     * ))
     *
     * // Release a room when done
     * try await chatClient.rooms.release("general-chat")
     * ```
     */
    var rooms: Rooms { get }

    /**
     * Provides access to the underlying connection to Ably for monitoring connectivity.
     *
     * - Returns: The Connection instance
     *
     * ## Example
     *
     * ```swift
     * let chatClient: ChatClient // existing ChatClient instance
     *
     * // Check current connection status
     * print("Status: \(chatClient.connection.status)")
     * print("Error: \(String(describing: chatClient.connection.error))")
     *
     * // Monitor connection changes
     * let subscription = chatClient.connection.onStatusChange { change in
     *     print("Connection: \(change.previous) -> \(change.current)")
     * }
     * ```
     */
    var connection: Connection { get }

    /**
     * Returns the clientId of the current client, if known.
     *
     * - Important: When using an Ably key for authentication, this value is determined immediately. If using a token,
     * the clientId is not known until the client has successfully connected to and authenticated with
     * the server. Use the `chatClient.connection.status` to check the connection status.
     *
     * - Returns: The clientId, or nil if unknown.
     */
    var clientID: String? { get }

    /**
     * Provides direct access to the underlying Ably Realtime client.
     *
     * Use this for advanced scenarios requiring direct Ably access. Most chat
     * operations should use the high-level chat SDK methods instead.
     *
     * - Note: Directly interacting with the Ably Realtime client can lead to
     * unexpected behavior.
     *
     * - Returns: The underlying Ably Realtime client instance
     */
    var realtime: Realtime { get }

    /**
     * The configuration options used to initialize the chat client.
     *
     * - Returns: The resolved client options including defaults
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
    // swiftlint:disable:next missing_docs
    public let realtime: ARTRealtime
    // swiftlint:disable:next missing_docs
    public let clientOptions: ChatClientOptions
    private let _rooms: DefaultRooms<DefaultRoomFactory<InternalRealtimeClientAdapter<ARTWrapperSDKProxyRealtime>>>
    // swiftlint:disable:next missing_docs
    public var rooms: some Rooms<ARTRealtimeChannel> {
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

    /**
     * Creates a new ChatClient instance for interacting with Ably Chat.
     *
     * The ChatClient is the main entry point for the Ably Chat SDK. It requires a Realtime client
     * and provides access to chat rooms through the rooms property.
     *
     * - Important: The Ably Realtime client must have a clientId set. This identifies
     * the user in chat rooms and is required for all chat operations.
     *
     * - Note: You can provide optional overrides to the ``ChatClient``, these will be merged
     * with the default options. See ``ChatClientOptions`` for the available options.
     *
     * - Parameters:
     *   - realtime: An initialized Ably Realtime client with a configured clientId
     *   - clientOptions: Optional configuration for the chat client
     *
     * ## Example - Preferred in production: Use auth URL that returns a JWT
     *
     * ```swift
     * import Ably
     * import AblyChat
     *
     * let realtimeOptions = ARTClientOptions()
     * realtimeOptions.authUrl = URL(string: "/api/ably-auth") // Your server endpoint that returns a JWT with clientId
     * realtimeOptions.authMethod = "POST"
     * let realtimeClientWithJWT = ARTRealtime(options: realtimeOptions)
     *
     * let chatClient = ChatClient(realtime: realtimeClientWithJWT)
     * ```
     *
     * ## Example - Alternative for development and server-side operations: Set clientId directly (requires API key)
     *
     * ```swift
     * let realtimeClientWithKey = ARTRealtime(key: "your-ably-api-key")
     * realtimeClientWithKey.clientId = "user-123"
     *
     * let chatClient = ChatClient(realtime: realtimeClientWithKey)
     * ```
     *
     * ## Example - With custom logging configuration: Defaults to LogLevel.error and console logging
     *
     * ```swift
     * let realtimeOptions = ARTClientOptions()
     * realtimeOptions.authUrl = URL(string: "/api/ably-auth") // Your server endpoint that returns a JWT with clientId
     * realtimeOptions.authMethod = "POST"
     * let realtimeClient = ARTRealtime(options: realtimeOptions)
     *
     * let chatClientWithLogging = ChatClient(
     *     realtime: realtimeClient,
     *     clientOptions: ChatClientOptions(
     *         logLevel: .debug,
     *         logHandler: YourLogHandler() // Implements `LogHandler.Simple` protocol
     *     )
     * )
     * ```
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

    // swiftlint:disable:next missing_docs
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
     * Creates a new ChatClientOptions instance.
     *
     * - Parameters:
     *   - logHandler: Optional custom log handler for capturing log messages
     *   - logLevel: The minimum log level for messages (defaults to `.error`)
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
