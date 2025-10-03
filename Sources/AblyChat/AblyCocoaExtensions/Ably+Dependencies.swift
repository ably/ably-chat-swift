import Ably

extension ARTRealtime: RealtimeClientProtocol {}
extension ARTWrapperSDKProxyRealtime: ProxyRealtimeClientProtocol {
    internal typealias Proxied = ARTRealtime
}

extension ARTRealtimeChannels: RealtimeChannelsProtocol {}
extension ARTWrapperSDKProxyRealtimeChannels: ProxyRealtimeChannelsProtocol {
    internal typealias Proxied = ARTRealtimeChannels
}

extension ARTRealtimeChannel: RealtimeChannelProtocol {}
extension ARTWrapperSDKProxyRealtimeChannel: ProxyRealtimeChannelProtocol {}

extension ARTRealtimePresence: RealtimePresenceProtocol {}
extension ARTWrapperSDKProxyRealtimePresence: RealtimePresenceProtocol {}

extension ARTRealtimeAnnotations: RealtimeAnnotationsProtocol {}
extension ARTWrapperSDKProxyRealtimeAnnotations: RealtimeAnnotationsProtocol {}

extension ARTConnection: CoreConnectionProtocol {}
