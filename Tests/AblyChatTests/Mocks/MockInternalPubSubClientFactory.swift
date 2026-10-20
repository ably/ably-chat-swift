@testable import AblyChat
import AblyPubSubDevice
import Foundation

final class MockInternalPubSubClientFactory: InternalPubSubClientFactory {
    private let createInternalPubSubClientReturnValue: InternalPubSubClientAdapter<WrapperSDKProxyRealtime>
    private(set) var createInternalPubSubClientArgument: WrapperSDKProxyRealtime?

    init(createInternalPubSubClientReturnValue: InternalPubSubClientAdapter<WrapperSDKProxyRealtime>) {
        self.createInternalPubSubClientReturnValue = createInternalPubSubClientReturnValue
    }

    func createInternalPubSubClient(_ ablyCocoaPubSubClient: WrapperSDKProxyRealtime) -> InternalPubSubClientAdapter<WrapperSDKProxyRealtime> {
        createInternalPubSubClientArgument = ablyCocoaPubSubClient
        return createInternalPubSubClientReturnValue
    }
}
