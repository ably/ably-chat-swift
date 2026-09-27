import AblyPubSubDevice

/// A mock subclass of ably-cocoa's `PubSubClient`.
///
/// This is used very little in the tests (only in `ChatClientTests`); elsewhere we work with protocol mocks.
class MockConcreteAblyCocoaRealtime: PubSubClient, @unchecked Sendable {
    /// Provides a convenience method for creating an `WrapperSDKProxyRealtime` (which doesn't have a public initializer).
    enum ProxyHelper {
        static func createProxy() -> WrapperSDKProxyRealtime {
            let sacrificialRealtime = PubSubDevice.createClient(options: .forNoop())
            // These agents are irrelevant
            return sacrificialRealtime.createWrapperSDKProxy(with: .init(agents: [:]))
        }
    }

    let createWrapperSDKProxyReturnValue: WrapperSDKProxyRealtime?

    init(createWrapperSDKProxyReturnValue: WrapperSDKProxyRealtime?) {
        self.createWrapperSDKProxyReturnValue = createWrapperSDKProxyReturnValue
        // `PubSubClient` is built by `PubSubDevice.createClient`, and exposes no
        // initializer to chain to, so this calls `NSObject`'s. The resulting
        // instance answers `createWrapperSDKProxy(with:)` and nothing else; the
        // tests that use it ask for nothing else.
        super.init()
    }

    private let mutex = NSLock()
    /// Access must be synchronized via ``mutex``.
    private(set) var _createWrapperSDKProxyOptionsArgument: WrapperSDKProxyOptions?

    var createWrapperSDKProxyOptionsArgument: WrapperSDKProxyOptions? {
        mutex.withLock {
            _createWrapperSDKProxyOptionsArgument
        }
    }

    override func createWrapperSDKProxy(with options: WrapperSDKProxyOptions) -> WrapperSDKProxyRealtime {
        guard let createWrapperSDKProxyReturnValue else {
            fatalError("createWrapperSDKProxyReturnValue must be set in order to call createWrapperSDKProxy(with:)")
        }

        mutex.withLock {
            _createWrapperSDKProxyOptionsArgument = options
        }

        return createWrapperSDKProxyReturnValue
    }
}

private extension ClientOptions {
    /// Client options with which you can instantiate an `PubSubClient` instance so that it will do nothing on instantiation.
    static func forNoop() -> ClientOptions {
        let result = ClientOptions()
        result.autoConnect = false
        result.key = "fake:key"
        return result
    }
}
