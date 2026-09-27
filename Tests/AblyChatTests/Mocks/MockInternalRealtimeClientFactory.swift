@testable import AblyChat
import AblyPubSubDevice
import Foundation

final class MockInternalRealtimeClientFactory: InternalRealtimeClientFactory {
    private let createInternalRealtimeClientReturnValue: InternalRealtimeClientAdapter<WrapperSDKProxyRealtime>
    private(set) var createInternalRealtimeClientArgument: WrapperSDKProxyRealtime?

    init(createInternalRealtimeClientReturnValue: InternalRealtimeClientAdapter<WrapperSDKProxyRealtime>) {
        self.createInternalRealtimeClientReturnValue = createInternalRealtimeClientReturnValue
    }

    func createInternalRealtimeClient(_ ablyCocoaRealtime: WrapperSDKProxyRealtime) -> InternalRealtimeClientAdapter<WrapperSDKProxyRealtime> {
        createInternalRealtimeClientArgument = ablyCocoaRealtime
        return createInternalRealtimeClientReturnValue
    }
}
