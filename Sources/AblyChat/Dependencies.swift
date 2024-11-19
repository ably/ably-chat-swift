import Ably

/// Expresses the requirements of the Ably realtime client that is supplied to the Chat SDK.
///
/// The `ARTRealtime` class from the ably-cocoa SDK implements this protocol.
public protocol RealtimeClientProtocol: ARTRealtimeProtocol, Sendable {
    associatedtype Channels: RealtimeChannelsProtocol

    // It’s not clear to me why ARTRealtimeProtocol doesn’t include this property. I briefly tried adding it but ran into compilation failures that it wasn’t immediately obvious how to fix.
    var channels: Channels { get }
}

/// Expresses the requirements of the object returned by ``RealtimeClientProtocol.channels``.
public protocol RealtimeChannelsProtocol: ARTRealtimeChannelsProtocol, Sendable {
    associatedtype Channel: RealtimeChannelProtocol

    // It’s not clear to me why ARTRealtimeChannelsProtocol doesn’t include this function (https://github.com/ably/ably-cocoa/issues/1968).
    func get(_ name: String, options: ARTRealtimeChannelOptions) -> Channel
}

/// Expresses the requirements of the object returned by ``RealtimeChannelsProtocol.get(_:)``.
public protocol RealtimeChannelProtocol: ARTRealtimeChannelProtocol, Sendable {}

/// Like (a subset of) `ARTRealtimeChannelOptions` but with value semantics. (It’s unfortunate that `ARTRealtimeChannelOptions` doesn’t have a `-copy` method.)
internal struct RealtimeChannelOptions {
    internal var modes: ARTChannelMode
    internal var params: [String: String]?

    internal init() {
        // Get our default values from ably-cocoa
        let artRealtimeChannelOptions = ARTRealtimeChannelOptions()
        modes = artRealtimeChannelOptions.modes
        params = artRealtimeChannelOptions.params
    }

    internal var toARTRealtimeChannelOptions: ARTRealtimeChannelOptions {
        let result = ARTRealtimeChannelOptions()
        result.modes = modes
        result.params = params
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

        return channels.get(name, options: resolvedOptions.toARTRealtimeChannelOptions)
    }
}
