import Ably

public protocol ChatClient: AnyObject, Sendable {
    var rooms: any Rooms { get }
    var connection: any Connection { get }
    var clientID: String { get }
    var realtime: any ARTRealtimeProtocol { get }
    var clientOptions: ClientOptions { get }
}

public final class DefaultChatClient: ChatClient {
    public init(realtime _: ARTRealtimeProtocol, clientOptions _: ClientOptions?) {
        // This one doesn’t do `fatalError`, so that I can call it in the example app
    }

    public var rooms: any Rooms {
        fatalError("Not yet implemented")
    }

    public var connection: any Connection {
        fatalError("Not yet implemented")
    }

    public var clientID: String {
        fatalError("Not yet implemented")
    }

    public var realtime: any ARTRealtimeProtocol {
        fatalError("Not yet implemented")
    }

    public var clientOptions: ClientOptions {
        fatalError("Not yet implemented")
    }
}

public struct ClientOptions: Sendable {
    public var logHandler: LogHandler?
    public var logLevel: LogLevel?

    public init(logHandler: (any LogHandler)? = nil, logLevel: LogLevel? = nil) {
        self.logHandler = logHandler
        self.logLevel = logLevel
    }
}
