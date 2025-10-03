import Ably

internal protocol ProxyRealtimeClientProtocol: RealtimeClientProtocol where Channels: ProxyRealtimeChannelsProtocol {
    associatedtype Proxied: RealtimeClientProtocol where Channels.Proxied == Proxied.Channels
}

internal protocol ProxyRealtimeChannelsProtocol: RealtimeChannelsProtocol where Channel: ProxyRealtimeChannelProtocol {
    associatedtype Proxied: RealtimeChannelsProtocol where Channel.Proxied == Proxied.Channel
}

internal protocol ProxyRealtimeChannelProtocol: Sendable, RealtimeChannelProtocol {
    associatedtype Proxied: RealtimeChannelProtocol

    var underlyingChannel: Proxied { get }
}

/// Expresses the requirements of the realtime client used by a ``ChatClient``.
internal protocol RealtimeClientProtocol: ARTRealtimeInstanceMethodsProtocol, Sendable {
    associatedtype Channels: RealtimeChannelsProtocol
    associatedtype Connection: CoreConnectionProtocol

    var channels: Channels { get }
    var connection: Connection { get }
}

/// Expresses the requirements of the object returned by ``RealtimeClientProtocol/channels``.
internal protocol RealtimeChannelsProtocol: ARTRealtimeChannelsProtocol, Sendable {
    associatedtype Channel: RealtimeChannelProtocol

    func get(_ name: String, options: ARTRealtimeChannelOptions) -> Channel
}

/// Expresses the requirements of the object returned by ``RealtimeChannelsProtocol/get(_:options:)``.
internal protocol RealtimeChannelProtocol: ARTRealtimeChannelProtocol, Sendable {
    associatedtype Presence: RealtimePresenceProtocol
    associatedtype Annotations: RealtimeAnnotationsProtocol

    var presence: Presence { get }
    var annotations: Annotations { get }
}

/// Expresses the requirements of the object returned by ``RealtimeChannelProtocol/presence``.
internal protocol RealtimePresenceProtocol: ARTRealtimePresenceProtocol, Sendable {}

/// Expresses the requirements of the object returned by ``RealtimeChannelProtocol/annotations``.
internal protocol RealtimeAnnotationsProtocol: ARTRealtimeAnnotationsProtocol, Sendable {}

/// Expresses the requirements of the object returned by ``RealtimeClientProtocol/connection``.
///
/// - Note: `Core` here is to disambiguate from the `Connection` protocol that a `ChatClient` exposes.
internal protocol CoreConnectionProtocol: ARTConnectionProtocol, Sendable {}
