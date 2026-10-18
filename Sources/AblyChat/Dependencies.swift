import AblyPubSubDevice

internal protocol ProxyPubSubClientProtocol: PubSubClientProtocol where Channels: ProxyRealtimeChannelsProtocol {
    associatedtype Proxied: PubSubClientProtocol where Channels.Proxied == Proxied.Channels
}

internal protocol ProxyRealtimeChannelsProtocol: RealtimeChannelsProtocol where Channel: ProxyRealtimeChannelProtocol {
    associatedtype Proxied: RealtimeChannelsProtocol where Channel.Proxied == Proxied.Channel
}

internal protocol ProxyRealtimeChannelProtocol: Sendable, RealtimeChannelProtocol {
    associatedtype Proxied: RealtimeChannelProtocol

    var underlyingChannel: Proxied { get }
}

/// Expresses the requirements of the Pub/Sub client used by a ``ChatClientProtocol``.
internal protocol PubSubClientProtocol: PubSubProtocol, Sendable {
    associatedtype Channels: RealtimeChannelsProtocol
    associatedtype Connection: CoreConnectionProtocol

    var channels: Channels { get }
    var connection: Connection { get }
}

/// Expresses the requirements of the object returned by ``PubSubClientProtocol/channels``.
internal protocol RealtimeChannelsProtocol: AblyPubSubDevice.RealtimeChannelsProtocol, Sendable {
    associatedtype Channel: RealtimeChannelProtocol

    func get(_ name: String, options: RealtimeChannelOptions) -> Channel
}

/// Expresses the requirements of the object returned by ``RealtimeChannelsProtocol/get(_:options:)``.
internal protocol RealtimeChannelProtocol: AblyPubSubDevice.RealtimeChannelProtocol, Sendable {
    associatedtype Presence: RealtimePresenceProtocol
    associatedtype Annotations: RealtimeAnnotationsProtocol

    var presence: Presence { get }
    var annotations: Annotations { get }
}

/// Expresses the requirements of the object returned by ``RealtimeChannelProtocol/presence``.
internal protocol RealtimePresenceProtocol: AblyPubSubDevice.RealtimePresenceProtocol, Sendable {}

/// Expresses the requirements of the object returned by ``RealtimeChannelProtocol/annotations``.
internal protocol RealtimeAnnotationsProtocol: AblyPubSubDevice.RealtimeAnnotationsProtocol, Sendable {}

/// Expresses the requirements of the object returned by ``PubSubClientProtocol/connection``.
///
/// - Note: `Core` here is to disambiguate from the `Connection` protocol that a `ChatClientProtocol` exposes.
internal protocol CoreConnectionProtocol: ConnectionProtocol, Sendable {}
