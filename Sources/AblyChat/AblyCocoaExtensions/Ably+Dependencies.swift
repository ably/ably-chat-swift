import AblyPubSubDevice

extension PubSubClient: RealtimeClientProtocol {}
extension WrapperSDKProxyRealtime: ProxyRealtimeClientProtocol {
    internal typealias Proxied = PubSubClient
}

extension RealtimeChannels: RealtimeChannelsProtocol {}
extension WrapperSDKProxyRealtimeChannels: ProxyRealtimeChannelsProtocol {
    internal typealias Proxied = RealtimeChannels
}

extension RealtimeChannel: RealtimeChannelProtocol {}
extension WrapperSDKProxyRealtimeChannel: ProxyRealtimeChannelProtocol {}

extension RealtimePresence: RealtimePresenceProtocol {}
extension WrapperSDKProxyRealtimePresence: RealtimePresenceProtocol {}

extension RealtimeAnnotations: RealtimeAnnotationsProtocol {}
extension WrapperSDKProxyRealtimeAnnotations: RealtimeAnnotationsProtocol {}

extension AblyPubSubDevice.Connection: CoreConnectionProtocol {}
