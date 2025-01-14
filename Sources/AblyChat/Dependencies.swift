import Ably

/// Expresses the requirements of the Ably realtime client that is supplied to the Chat SDK.
///
/// The `ARTRealtime` class from the ably-cocoa SDK implements this protocol.
public protocol RealtimeClientProtocol: ARTRealtimeProtocol, Sendable {
    associatedtype Channels: RealtimeChannelsProtocol
    associatedtype Connection: ConnectionProtocol

    var channels: Channels { get }
    var connection: Connection { get }
}

/// Expresses the requirements of the object returned by ``RealtimeClientProtocol/channels``.
public protocol RealtimeChannelsProtocol: ARTRealtimeChannelsProtocol, Sendable {
    associatedtype Channel: RealtimeChannelProtocol

    func get(_ name: String, options: ARTRealtimeChannelOptions) -> Channel
}

/// Expresses the requirements of the object returned by ``RealtimeChannelsProtocol/get(_:options:)``.
public protocol RealtimeChannelProtocol: ARTRealtimeChannelProtocol, Sendable {}

/// Expresses the requirements of the object returned by ``RealtimeClientProtocol/connection``.
public protocol ConnectionProtocol: ARTConnectionProtocol, Sendable {}

/// Like (a subset of) `ARTRealtimeChannelOptions` but with value semantics. (It’s unfortunate that `ARTRealtimeChannelOptions` doesn’t have a `-copy` method.)
internal struct RealtimeChannelOptions {
    internal var modes: ARTChannelMode
    internal var params: [String: String]?
    internal var attachOnSubscribe: Bool

    internal init() {
        // Get our default values from ably-cocoa
        let artRealtimeChannelOptions = ARTRealtimeChannelOptions()
        modes = artRealtimeChannelOptions.modes
        params = artRealtimeChannelOptions.params
        attachOnSubscribe = artRealtimeChannelOptions.attachOnSubscribe
    }

    internal var toARTRealtimeChannelOptions: ARTRealtimeChannelOptions {
        let result = ARTRealtimeChannelOptions()
        result.modes = modes
        result.params = params
        result.attachOnSubscribe = attachOnSubscribe
        return result
    }
}

internal extension RealtimeClientProtocol {
    // Function to get the channel with merged options
    func getChannel(_ name: String, opts: RealtimeChannelOptions? = nil) -> any RealtimeChannelProtocol {
        var resolvedOptions = opts ?? .init()

        // Add in the default params
        resolvedOptions.params = (resolvedOptions.params ?? [:]).merging(
            defaultChannelParams
        ) { _, new
            in new
        }

        // CHA-GP2a
        resolvedOptions.attachOnSubscribe = false

        return channels.get(name, options: resolvedOptions.toARTRealtimeChannelOptions)
    }
}
