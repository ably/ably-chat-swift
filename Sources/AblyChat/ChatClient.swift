import Ably

@MainActor
public protocol ChatClient: AnyObject, Sendable {
    /**
     * Returns the rooms object, which provides access to chat rooms.
     *
     * - Returns: The rooms object.
     */
    nonisolated var rooms: any Rooms { get }

    /**
     * Returns the underlying connection to Ably, which can be used to monitor the clients
     * connection to Ably servers.
     *
     * - Returns: The connection object.
     */
    nonisolated var connection: any Connection { get }

    /**
     * Returns the clientId of the current client.
     *
     * - Returns: The clientId.
     */
    var clientID: String { get }

    /**
     * Returns the underlying Ably Realtime client.
     *
     * - Returns: The Ably Realtime client.
     */
    nonisolated var realtime: RealtimeClient { get }

    /**
     * Returns the resolved client options for the client, including any defaults that have been set.
     *
     * - Returns: The client options.
     */
    nonisolated var clientOptions: ChatClientOptions { get }
}

public typealias RealtimeClient = any RealtimeClientProtocol

@MainActor
internal protocol InternalRealtimeClientFactory {
    func createInternalRealtimeClient(_ ablyCocoaRealtime: any RealtimeClientProtocol) -> any InternalRealtimeClientProtocol
}

internal final class DefaultInternalRealtimeClientFactory: InternalRealtimeClientFactory {
    internal func createInternalRealtimeClient(_ ablyCocoaRealtime: any RealtimeClientProtocol) -> any InternalRealtimeClientProtocol {
        InternalRealtimeClientAdapter(underlying: ablyCocoaRealtime)
    }
}

/**
 * This is the core client for Ably chat. It provides access to chat rooms.
 */
public class DefaultChatClient: ChatClient {
    public nonisolated let realtime: RealtimeClient
    public nonisolated let clientOptions: ChatClientOptions
    public let rooms: Rooms
    private let logger: InternalLogger

    // (CHA-CS1) Every chat client has a status, which describes the current status of the connection.
    // (CHA-CS4) The chat client must allow its connection status to be observed by clients.
    public let connection: any Connection

    /**
     * Constructor for Chat
     *
     * - Parameters:
     *   - realtime: The Ably Realtime client. If this is an instance of `ARTRealtime` from the ably-cocoa SDK, then its `dispatchQueue` option must be the main queue (this is its default behaviour).
     *   - clientOptions: The client options.
     */
    public convenience init(realtime suppliedRealtime: any SuppliedRealtimeClientProtocol, clientOptions: ChatClientOptions?) {
        self.init(realtime: suppliedRealtime, clientOptions: clientOptions, internalRealtimeClientFactory: DefaultInternalRealtimeClientFactory())
    }

    internal init(realtime suppliedRealtime: any SuppliedRealtimeClientProtocol, clientOptions: ChatClientOptions?, internalRealtimeClientFactory: any InternalRealtimeClientFactory, timerManager: TimerManagerProtocol = TimerManager(clock: SystemClock())) {
        self.realtime = suppliedRealtime
        self.clientOptions = clientOptions ?? .init()

        let realtime = suppliedRealtime.createWrapperSDKProxy(with: .init(agents: agents))
        let internalRealtime = internalRealtimeClientFactory.createInternalRealtimeClient(realtime)

        logger = DefaultInternalLogger(logHandler: self.clientOptions.logHandler, logLevel: self.clientOptions.logLevel)
        let roomFactory = DefaultRoomFactory()
        rooms = DefaultRooms(realtime: internalRealtime, clientOptions: self.clientOptions, logger: logger, roomFactory: roomFactory)
        connection = DefaultConnection(realtime: internalRealtime, timerManager: timerManager)
    }

    public nonisolated var clientID: String {
        guard let clientID = realtime.clientId else {
            fatalError("Ensure your Realtime instance is initialized with a clientId.")
        }
        return clientID
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
     * By default, ``LogLevel/error`` will be used.
     */
    public var logLevel: LogLevel?

    public init(logHandler: (any LogHandler)? = nil, logLevel: LogLevel? = nil) {
        self.logHandler = logHandler
        self.logLevel = logLevel
    }

    /// Used for comparing these instances in tests without having to make this Equatable, which I’m not yet sure makes sense (we’ll decide in https://github.com/ably-labs/ably-chat-swift/issues/10)
    internal func isEqualForTestPurposes(_ other: ChatClientOptions) -> Bool {
        logHandler === other.logHandler && logLevel == other.logLevel
    }
}
