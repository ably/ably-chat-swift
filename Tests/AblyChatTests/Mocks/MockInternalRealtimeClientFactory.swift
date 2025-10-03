import Ably
@testable import AblyChat
import Foundation

final class MockInternalRealtimeClientFactory: InternalRealtimeClientFactory {
    private let createInternalRealtimeClientReturnValue: InternalRealtimeClientAdapter<ARTWrapperSDKProxyRealtime>
    private(set) var createInternalRealtimeClientArgument: ARTWrapperSDKProxyRealtime?

    init(createInternalRealtimeClientReturnValue: InternalRealtimeClientAdapter<ARTWrapperSDKProxyRealtime>) {
        self.createInternalRealtimeClientReturnValue = createInternalRealtimeClientReturnValue
    }

    func createInternalRealtimeClient(_ ablyCocoaRealtime: ARTWrapperSDKProxyRealtime) -> InternalRealtimeClientAdapter<ARTWrapperSDKProxyRealtime> {
        createInternalRealtimeClientArgument = ablyCocoaRealtime
        return createInternalRealtimeClientReturnValue
    }
}
