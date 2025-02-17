import Ably

extension ARTRealtime: SuppliedRealtimeClientProtocol {}

extension ARTWrapperSDKProxyRealtime: RealtimeClientProtocol {}

extension ARTRealtimeChannels: RealtimeChannelsProtocol {}
extension ARTWrapperSDKProxyRealtimeChannels: RealtimeChannelsProtocol {}

extension ARTRealtimeChannel: RealtimeChannelProtocol {}
extension ARTWrapperSDKProxyRealtimeChannel: RealtimeChannelProtocol {}

extension ARTRealtimePresence: RealtimePresenceProtocol {}
extension ARTWrapperSDKProxyRealtimePresence: RealtimePresenceProtocol {}

extension ARTConnection: ConnectionProtocol {}
