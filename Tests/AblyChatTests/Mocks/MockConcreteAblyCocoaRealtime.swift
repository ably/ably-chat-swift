import Ably

/// A mock subclass of ably-cocoa's `ARTRealtime`.
///
/// This is used very little in the tests (only in `DefaultChatClientTests`); elsewhere we work with protocol mocks.
class MockConcreteAblyCocoaRealtime: ARTRealtime, @unchecked Sendable {
    required init(token _: String) {
        fatalError("init(token:) has not been implemented")
    }

    required init(key _: String) {
        fatalError("init(key:) has not been implemented")
    }

    required init(options _: ARTClientOptions) {
        fatalError("init(options:) has not been implemented")
    }

    /// Provides a convenience method for creating an `ARTWrapperSDKProxyRealtime` (which doesn't have a public initializer).
    enum ProxyHelper {
        static func createProxy() -> ARTWrapperSDKProxyRealtime {
            let sacrificialRealtime = ARTRealtime(options: .forNoop())
            // These agents are irrelevant
            return sacrificialRealtime.createWrapperSDKProxy(with: .init(agents: [:]))
        }
    }

    let createWrapperSDKProxyReturnValue: ARTWrapperSDKProxyRealtime?

    init(createWrapperSDKProxyReturnValue: ARTWrapperSDKProxyRealtime?) {
        self.createWrapperSDKProxyReturnValue = createWrapperSDKProxyReturnValue
        super.init(options: .forNoop())
    }

    private let mutex = NSLock()
    /// Access must be synchronized via ``mutex``.
    private(set) var _createWrapperSDKProxyOptionsArgument: ARTWrapperSDKProxyOptions?

    var createWrapperSDKProxyOptionsArgument: ARTWrapperSDKProxyOptions? {
        mutex.withLock {
            _createWrapperSDKProxyOptionsArgument
        }
    }

    override func createWrapperSDKProxy(with options: ARTWrapperSDKProxyOptions) -> ARTWrapperSDKProxyRealtime {
        guard let createWrapperSDKProxyReturnValue else {
            fatalError("createWrapperSDKProxyReturnValue must be set in order to call createWrapperSDKProxy(with:)")
        }

        mutex.withLock {
            _createWrapperSDKProxyOptionsArgument = options
        }

        return createWrapperSDKProxyReturnValue
    }
}

private extension ARTClientOptions {
    /// Client options with which you can instantiate an `ARTRealtime` instance so that it will do nothing on instantiation.
    static func forNoop() -> ARTClientOptions {
        let result = ARTClientOptions()
        result.autoConnect = false
        result.key = "fake:key"
        return result
    }
}
