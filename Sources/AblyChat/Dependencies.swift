import Ably

/// Expresses the requirements of the Ably realtime client that is supplied to the Chat SDK.
///
/// The `ARTRealtime` class from the ably-cocoa SDK implements this protocol.
public protocol SuppliedRealtimeClientProtocol: Sendable, RealtimeClientProtocol {
    associatedtype ProxyClient: RealtimeClientProtocol

    func createWrapperSDKProxy(with options: ARTWrapperSDKProxyOptions) -> ProxyClient
}

/// Expresses the requirements of the object returned by ``SuppliedRealtimeClientProtocol/createWrapperSDKProxy(with:)``.
public protocol RealtimeClientProtocol: ARTRealtimeInstanceMethodsProtocol, Sendable {
    associatedtype Channels: RealtimeChannelsProtocol
    associatedtype Connection: CoreConnectionProtocol

    var channels: Channels { get }
    var connection: Connection { get }
}

/// Expresses the requirements of the object returned by ``RealtimeClientProtocol/channels``.
public protocol RealtimeChannelsProtocol: ARTRealtimeChannelsProtocol, Sendable {
    associatedtype Channel: RealtimeChannelProtocol

    func get(_ name: String, options: ARTRealtimeChannelOptions) -> Channel
}

/// Expresses the requirements of the object returned by ``RealtimeChannelsProtocol/get(_:options:)``.
public protocol RealtimeChannelProtocol: ARTRealtimeChannelProtocol, Sendable {
    associatedtype Presence: RealtimePresenceProtocol
    associatedtype Annotations: RealtimeAnnotationsProtocol

    var presence: Presence { get }
    var annotations: Annotations { get }
}

/// Expresses the requirements of the object returned by ``RealtimeChannelProtocol/presence``.
public protocol RealtimePresenceProtocol: ARTRealtimePresenceProtocol, Sendable {}

/// Expresses the requirements of the object returned by ``RealtimeChannelProtocol/annotations``.
public protocol RealtimeAnnotationsProtocol: ARTRealtimeAnnotationsProtocol, Sendable {}

/// Expresses the requirements of the object returned by ``RealtimeClientProtocol/connection``.
///
/// - Note: `Core` here is to disambiguate from the `Connection` protocol that a `ChatClient` exposes.
public protocol CoreConnectionProtocol: ARTConnectionProtocol, Sendable {}
