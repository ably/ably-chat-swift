import AblyPubSubDevice

/// The interface that the Chat SDK uses to access ably-cocoa's realtime functionality.
///
/// The idea is to translate ably-cocoa's `RealtimeProtocol` interface into something that's more pleasant to use from Swift (and easier to mock), by using:
///
/// - `async` methods instead of callbacks
/// - typed throws (of our error type `ErrorInfo`)
/// - `JSONValue` instead of `Any`
///
/// Hopefully we will eventually be able to remove this interface once we've improved the experience of using ably-cocoa from Swift (https://github.com/ably/ably-cocoa/issues/1967).
///
/// This protocol only contains the functionality from ably-cocoa that we're actually currently using in the Chat SDK, so you might need to add new properties and methods to it over time.
///
/// The default implementation of this protocol is ``InternalRealtimeClientAdapter``, which uses an underlying ably-cocoa `RealtimeProtocol` object.
///
/// All of the types here are @MainActor to make it easy to write mocks for them (the SDK code that uses them, as well as the tests that would use their mocks, is all @MainActor).
@MainActor
internal protocol InternalRealtimeClientProtocol: AnyObject, Sendable {
    associatedtype Channels: InternalRealtimeChannelsProtocol
    associatedtype Connection: InternalConnectionProtocol
    associatedtype HTTPPaginatedResponse: InternalHTTPPaginatedResponseProtocol

    var clientId: String? { get }
    func request(_ method: String, path: String, params: [String: String]?, body: Any?, headers: [String: String]?) async throws(ErrorInfo) -> HTTPPaginatedResponse

    var channels: Channels { get }
    var connection: Connection { get }
}

/// Expresses the requirements of the object returned by ``InternalRealtimeClientProtocol/channels``.
@MainActor
internal protocol InternalRealtimeChannelsProtocol: AnyObject, Sendable {
    associatedtype Channel: InternalRealtimeChannelProtocol

    func get(_ name: String, options: RealtimeChannelOptions) -> Channel

    func release(_ name: String)
}

/// Expresses the requirements of the object returned by ``InternalRealtimeChannelsProtocol/get(_:options:)``.
///
/// We choose to mark the channel's mutable state as `async`. This is a way of highlighting at the call site of accessing this state that, since `RealtimeChannel` mutates this state on a separate thread, it's possible for this state to have changed since the last time you checked it, or since the last time you performed an operation that might have mutated it, or since the last time you recieved an event informing you that it changed. To be clear, marking these as `async` doesn't _solve_ these issues; it just makes them a bit more visible. We'll decide how to address them in https://github.com/ably-labs/ably-chat-swift/issues/49.
@MainActor
internal protocol InternalRealtimeChannelProtocol: AnyObject, Sendable {
    associatedtype Proxied: RealtimeChannelProtocol
    associatedtype Presence: InternalRealtimePresenceProtocol
    associatedtype Annotations: InternalRealtimeAnnotationsProtocol

    /// The ably-cocoa realtime channel wrapped by the proxy channel wrapped by this channel (e.g. the `RealtimeChannel` that underlies the `WrapperSDKProxyRealtimeChannel` that underlies this `InternalRealtimeChannelProtocol`).
    ///
    /// We need to be able to access this so that we can return it from the `channel` methods in the SDK's public API, which allow users of the SDK to access the realtime channels that the SDK uses.
    var proxied: Proxied { get }

    var presence: Presence { get }

    var annotations: Annotations { get }

    func attach() async throws(ErrorInfo)
    func detach() async throws(ErrorInfo)
    var name: String { get }
    var state: RealtimeChannelState { get }
    var errorReason: ErrorInfo? { get }
    func on(_ cb: @escaping @MainActor (ChannelStateChange) -> Void) -> EventListener
    func on(_ event: ChannelEvent, callback cb: @escaping @MainActor (ChannelStateChange) -> Void) -> EventListener
    func once(_ cb: @escaping @MainActor (ChannelStateChange) -> Void) -> EventListener
    func once(_ event: ChannelEvent, callback cb: @escaping @MainActor (ChannelStateChange) -> Void) -> EventListener
    func unsubscribe(_: EventListener?)
    func publish(_ name: String?, data: JSONValue?, extras: [String: JSONValue]?) async throws(ErrorInfo)
    func subscribe(_ callback: @escaping @MainActor (AblyPubSubDevice.Message) -> Void) -> EventListener?
    func subscribe(_ name: String, callback: @escaping @MainActor (AblyPubSubDevice.Message) -> Void) -> EventListener?
    var properties: ChannelProperties { get }
    func off(_ listener: EventListener)
}

/// Expresses the requirements of the object returned by ``InternalRealtimeChannelProtocol/presence``.
@MainActor
internal protocol InternalRealtimePresenceProtocol: AnyObject, Sendable {
    func get() async throws(ErrorInfo) -> [PresenceMessage]
    func get(_ query: RealtimePresenceQuery) async throws(ErrorInfo) -> [PresenceMessage]
    func enter(_ data: JSONObject?) async throws(ErrorInfo)
    func leave(_ data: JSONObject?) async throws(ErrorInfo)
    func update(_ data: JSONObject?) async throws(ErrorInfo)
    func subscribe(_ callback: @escaping @MainActor (AblyPubSubDevice.PresenceMessage) -> Void) -> EventListener?
    func subscribe(_ action: PresenceAction, callback: @escaping @MainActor (AblyPubSubDevice.PresenceMessage) -> Void) -> EventListener?
    func unsubscribe(_ listener: EventListener)
}

/// Expresses the requirements of the object returned by ``InternalRealtimeChannelProtocol/annotations``.
@MainActor
internal protocol InternalRealtimeAnnotationsProtocol: AnyObject, Sendable {
    func subscribe(_ callback: @escaping @MainActor (AblyPubSubDevice.Annotation) -> Void) -> EventListener?
    func subscribe(_ type: String, callback: @escaping @MainActor (AblyPubSubDevice.Annotation) -> Void) -> EventListener?
}

/// Expresses the requirements of the object returned by ``InternalRealtimeClientProtocol/connection``.
@MainActor
internal protocol InternalConnectionProtocol: AnyObject, Sendable {
    var state: RealtimeConnectionState { get }
    var errorReason: ErrorInfo? { get }

    func on(_ cb: @escaping @MainActor (ConnectionStateChange) -> Void) -> EventListener
    func off(_ listener: EventListener)
}

/// Expresses the requirements of the paginated response returned by ``InternalRealtimeClientProtocol/request(_:path:params:body:headers:)``.
@MainActor
internal protocol InternalHTTPPaginatedResponseProtocol: AnyObject, Sendable {
    var items: [JSONValue] { get }
    var hasNext: Bool { get }
    var isLast: Bool { get }
    var statusCode: Int { get }

    func next() async throws(ErrorInfo) -> Self?
    func first() async throws(ErrorInfo) -> Self
}

/// Converts a `@MainActor` callback into one that can be passed as a callback to ably-cocoa.
///
/// The returned callback asserts that it is called on the main thread and then synchronously calls the passed callback. It also allows non-`Sendable` values to be passed from ably-cocoa to the passed callback.
///
/// The main thread assertion is our way of asserting the requirement, documented in the `ChatClient` initializer, that the ably-cocoa client must be using the main queue as its `dispatchQueue`. (This is the only way we can do it without accessing private ably-cocoa API, since we don't publicly expose the options that a client is using.)
///
/// - Warning: You must be sure that after ably-cocoa calls the returned callback, it will not modify any of the mutable state contained inside the argument that it passes to the callback. This is true of the two non-`Sendable` types with which we're currently using it; namely `Message` and `PresenceMessage`. Ideally, we would instead annotate these callback arguments in ably-cocoa with `NS_SWIFT_SENDING`, to allow us to then mark the corresponding argument in these callbacks as `sending` and not have to circumvent compiler sendability checking, but as of Xcode 16.1 this annotation does yet not seem to have any effect; see [ably-cocoa#1967](https://github.com/ably/ably-cocoa/issues/1967).
private func toAblyCocoaCallback<Arg>(_ callback: @escaping @MainActor (Arg) -> Void) -> (Arg) -> Void {
    { arg in
        let sendingBox = UnsafeSendingBox(value: arg)

        // We use `preconditionIsolated` in addition to `assumeIsolated` because only the former accepts a message.
        MainActor.preconditionIsolated("The Ably Chat SDK requires that your ARTRealtime instance be using the main queue as its dispatchQueue.")
        MainActor.assumeIsolated {
            callback(sendingBox.value)
        }
    }
}

/// A box that makes the compiler ignore that a non-Sendable value is crossing an isolation boundary. Used by `toAblyCocoaCallback`; don't use it elsewhere unless you know what you're doing.
private final class UnsafeSendingBox<T>: @unchecked Sendable {
    var value: T

    init(value: T) {
        self.value = value
    }
}

internal final class InternalRealtimeClientAdapter<Underlying: ProxyRealtimeClientProtocol>: InternalRealtimeClientProtocol {
    private let underlying: Underlying
    internal let channels: InternalRealtimeChannelsAdapter<Underlying.Channels>
    internal let connection: InternalConnectionAdapter<Underlying.Connection>

    internal init(underlying: Underlying) {
        self.underlying = underlying
        channels = .init(underlying: underlying.channels)
        connection = .init(underlying: underlying.connection)
    }

    internal var clientId: String? {
        underlying.clientId
    }

    internal func request(_ method: String, path: String, params: [String: String]?, body: Any?, headers: [String: String]?) async throws(ErrorInfo) -> InternalHTTPPaginatedResponseAdapter {
        do {
            let artResponse = try await withCheckedContinuation { (continuation: CheckedContinuation<Result<AblyPubSubDevice.HTTPPaginatedResponse, AblyPubSubDevice.ErrorInfo>, _>) in
                do {
                    try underlying.request(method, path: path, params: params, body: body, headers: headers) { response, error in
                        if let error {
                            continuation.resume(returning: .failure(error))
                        } else if let response {
                            continuation.resume(returning: .success(response))
                        } else {
                            preconditionFailure("There is no error, so expected a response")
                        }
                    }
                } catch {
                    // This is a weird bit of API design in ably-cocoa (see https://github.com/ably/ably-cocoa/issues/2043 for fixing it); it throws an error to indicate a programmer error (it should be using exceptions). Since the type of the thrown error is NSError and not ErrorInfo, which would mess up our typed throw, let's not try and propagate it.
                    fatalError("ably-cocoa request threw an error - this indicates a programmer error")
                }
            }.get()
            return InternalHTTPPaginatedResponseAdapter(underlying: artResponse)
        } catch {
            throw .init(ablyCocoaError: error)
        }
    }
}

internal final class InternalHTTPPaginatedResponseAdapter: InternalHTTPPaginatedResponseProtocol {
    private let underlying: AblyPubSubDevice.HTTPPaginatedResponse

    internal init(underlying: AblyPubSubDevice.HTTPPaginatedResponse) {
        self.underlying = underlying
    }

    internal var items: [JSONValue] {
        underlying.items.map { JSONValue(ablyCocoaData: $0) }
    }

    internal var hasNext: Bool {
        underlying.hasNext
    }

    internal var isLast: Bool {
        underlying.isLast
    }

    internal var statusCode: Int {
        underlying.statusCode
    }

    internal func next() async throws(ErrorInfo) -> InternalHTTPPaginatedResponseAdapter? {
        do {
            return try await withCheckedContinuation { (continuation: CheckedContinuation<Result<InternalHTTPPaginatedResponseAdapter?, AblyPubSubDevice.ErrorInfo>, _>) in
                underlying.next { response, error in
                    if let error {
                        continuation.resume(returning: .failure(error))
                    } else if let response {
                        continuation.resume(returning: .success(InternalHTTPPaginatedResponseAdapter(underlying: response)))
                    } else {
                        continuation.resume(returning: .success(nil))
                    }
                }
            }.get()
        } catch {
            throw .init(ablyCocoaError: error)
        }
    }

    internal func first() async throws(ErrorInfo) -> InternalHTTPPaginatedResponseAdapter {
        do {
            return try await withCheckedContinuation { (continuation: CheckedContinuation<Result<InternalHTTPPaginatedResponseAdapter, AblyPubSubDevice.ErrorInfo>, _>) in
                underlying.first { response, error in
                    if let error {
                        continuation.resume(returning: .failure(error))
                    } else if let response {
                        continuation.resume(returning: .success(InternalHTTPPaginatedResponseAdapter(underlying: response)))
                    } else {
                        preconditionFailure("There is no error, so expected a response")
                    }
                }
            }.get()
        } catch {
            throw .init(ablyCocoaError: error)
        }
    }
}

internal final class InternalConnectionAdapter<Underlying: CoreConnectionProtocol>: InternalConnectionProtocol {
    private let underlying: Underlying

    internal init(underlying: Underlying) {
        self.underlying = underlying
    }

    internal var state: RealtimeConnectionState {
        underlying.state
    }

    internal var errorReason: ErrorInfo? {
        .init(optionalAblyCocoaError: underlying.errorReason)
    }

    internal func on(_ cb: @escaping @MainActor (ConnectionStateChange) -> Void) -> EventListener {
        underlying.on(toAblyCocoaCallback { artConnectionStateChange in
            cb(.init(ablyCocoaConnectionStateChange: artConnectionStateChange))
        })
    }

    internal func off(_ listener: EventListener) {
        underlying.off(listener)
    }
}

internal final class InternalRealtimeAnnotationsAdapter<Underlying: RealtimeAnnotationsProtocol>: InternalRealtimeAnnotationsProtocol {
    private let underlying: Underlying

    internal init(underlying: Underlying) {
        self.underlying = underlying
    }

    internal func subscribe(_ callback: @escaping @MainActor @Sendable (AblyPubSubDevice.Annotation) -> Void) -> EventListener? {
        underlying.subscribe(toAblyCocoaCallback(callback))
    }

    internal func subscribe(_ type: String, callback: @escaping @MainActor @Sendable (AblyPubSubDevice.Annotation) -> Void) -> EventListener? {
        underlying.subscribe(type, callback: toAblyCocoaCallback(callback))
    }

    internal func unsubscribe(_ listener: EventListener) {
        underlying.unsubscribe(listener)
    }
}

internal final class InternalRealtimePresenceAdapter<Underlying: RealtimePresenceProtocol>: InternalRealtimePresenceProtocol {
    private let underlying: Underlying

    internal init(underlying: Underlying) {
        self.underlying = underlying
    }

    internal func get() async throws(ErrorInfo) -> [PresenceMessage] {
        do {
            return try await withCheckedContinuation { (continuation: CheckedContinuation<Result<[PresenceMessage], AblyPubSubDevice.ErrorInfo>, _>) in
                underlying.get { members, error in
                    if let error {
                        continuation.resume(returning: .failure(error))
                    } else if let members {
                        continuation.resume(returning: .success(members.map { .init(ablyCocoaPresenceMessage: $0) }))
                    } else {
                        preconditionFailure("There is no error, so expected members")
                    }
                }
            }.get()
        } catch {
            throw .init(ablyCocoaError: error)
        }
    }

    internal func get(_ query: RealtimePresenceQuery) async throws(ErrorInfo) -> [PresenceMessage] {
        do {
            return try await withCheckedContinuation { (continuation: CheckedContinuation<Result<[PresenceMessage], AblyPubSubDevice.ErrorInfo>, _>) in
                underlying.get(query) { members, error in
                    if let error {
                        continuation.resume(returning: .failure(error))
                    } else if let members {
                        continuation.resume(returning: .success(members.map { .init(ablyCocoaPresenceMessage: $0) }))
                    } else {
                        preconditionFailure("There is no error, so expected members")
                    }
                }
            }.get()
        } catch {
            throw .init(ablyCocoaError: error)
        }
    }

    internal func leave(_ data: JSONObject?) async throws(ErrorInfo) {
        do {
            try await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, AblyPubSubDevice.ErrorInfo>, _>) in
                underlying.leave(data?.toAblyCocoaData) { error in
                    if let error {
                        continuation.resume(returning: .failure(error))
                    } else {
                        continuation.resume(returning: .success(()))
                    }
                }
            }.get()
        } catch {
            throw .init(ablyCocoaError: error)
        }
    }

    internal func enter(_ data: JSONObject?) async throws(ErrorInfo) {
        do {
            try await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, AblyPubSubDevice.ErrorInfo>, _>) in
                underlying.enter(data?.toAblyCocoaData) { error in
                    if let error {
                        continuation.resume(returning: .failure(error))
                    } else {
                        continuation.resume(returning: .success(()))
                    }
                }
            }.get()
        } catch {
            throw .init(ablyCocoaError: error)
        }
    }

    internal func update(_ data: JSONObject?) async throws(ErrorInfo) {
        do {
            try await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, AblyPubSubDevice.ErrorInfo>, _>) in
                underlying.update(data?.toAblyCocoaData) { error in
                    if let error {
                        continuation.resume(returning: .failure(error))
                    } else {
                        continuation.resume(returning: .success(()))
                    }
                }
            }.get()
        } catch {
            throw .init(ablyCocoaError: error)
        }
    }

    internal func subscribe(_ callback: @escaping @MainActor (AblyPubSubDevice.PresenceMessage) -> Void) -> EventListener? {
        underlying.subscribe(toAblyCocoaCallback(callback))
    }

    internal func subscribe(_ action: PresenceAction, callback: @escaping @MainActor (AblyPubSubDevice.PresenceMessage) -> Void) -> EventListener? {
        underlying.subscribe(action, callback: toAblyCocoaCallback(callback))
    }

    internal func unsubscribe(_ listener: EventListener) {
        underlying.unsubscribe(listener)
    }
}

internal final class InternalRealtimeChannelAdapter<Underlying: ProxyRealtimeChannelProtocol>: InternalRealtimeChannelProtocol {
    internal let underlying: Underlying
    internal let proxied: Underlying.Proxied
    internal let presence: InternalRealtimePresenceAdapter<Underlying.Presence>
    internal let annotations: InternalRealtimeAnnotationsAdapter<Underlying.Annotations>

    internal init(underlying: Underlying) {
        self.underlying = underlying
        proxied = underlying.underlyingChannel
        presence = .init(underlying: underlying.presence)
        annotations = .init(underlying: underlying.annotations)
    }

    internal var name: String {
        underlying.name
    }

    internal var state: RealtimeChannelState {
        underlying.state
    }

    internal var errorReason: ErrorInfo? {
        .init(optionalAblyCocoaError: underlying.errorReason)
    }

    internal var properties: ChannelProperties {
        underlying.properties
    }

    internal func attach() async throws(ErrorInfo) {
        do {
            try await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, AblyPubSubDevice.ErrorInfo>, _>) in
                underlying.attach { error in
                    if let error {
                        continuation.resume(returning: .failure(error))
                    } else {
                        continuation.resume(returning: .success(()))
                    }
                }
            }.get()
        } catch {
            throw .init(ablyCocoaError: error)
        }
    }

    internal func detach() async throws(ErrorInfo) {
        do {
            try await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, AblyPubSubDevice.ErrorInfo>, _>) in
                underlying.detach { error in
                    if let error {
                        continuation.resume(returning: .failure(error))
                    } else {
                        continuation.resume(returning: .success(()))
                    }
                }
            }.get()
        } catch {
            throw .init(ablyCocoaError: error)
        }
    }

    internal func publish(_ name: String?, data: JSONValue?, extras: [String: JSONValue]?) async throws(ErrorInfo) {
        do {
            try await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, AblyPubSubDevice.ErrorInfo>, _>) in
                underlying.publish(name, data: data?.toAblyCocoaData, extras: extras?.toARTJsonCompatible) { error in
                    if let error {
                        continuation.resume(returning: .failure(error))
                    } else {
                        continuation.resume(returning: .success(()))
                    }
                }
            }.get()
        } catch {
            throw .init(ablyCocoaError: error)
        }
    }

    internal func on(_ cb: @escaping @MainActor (ChannelStateChange) -> Void) -> EventListener {
        underlying.on(toAblyCocoaCallback { artChannelStateChange in
            cb(.init(ablyCocoaChannelStateChange: artChannelStateChange))
        })
    }

    internal func on(_ event: ChannelEvent, callback cb: @escaping @MainActor (ChannelStateChange) -> Void) -> EventListener {
        underlying.on(event, callback: toAblyCocoaCallback { artChannelStateChange in
            cb(.init(ablyCocoaChannelStateChange: artChannelStateChange))
        })
    }

    internal func once(_ cb: @escaping @MainActor (ChannelStateChange) -> Void) -> EventListener {
        underlying.once(toAblyCocoaCallback { artChannelStateChange in
            cb(.init(ablyCocoaChannelStateChange: artChannelStateChange))
        })
    }

    internal func once(_ event: ChannelEvent, callback cb: @escaping @MainActor (ChannelStateChange) -> Void) -> EventListener {
        underlying.once(event, callback: toAblyCocoaCallback { artChannelStateChange in
            cb(.init(ablyCocoaChannelStateChange: artChannelStateChange))
        })
    }

    internal func unsubscribe(_ listener: EventListener?) {
        underlying.unsubscribe(listener)
    }

    internal func subscribe(_ name: String, callback: @escaping @MainActor (AblyPubSubDevice.Message) -> Void) -> EventListener? {
        underlying.subscribe(name, callback: toAblyCocoaCallback(callback))
    }

    internal func subscribe(_ callback: @escaping @MainActor (AblyPubSubDevice.Message) -> Void) -> EventListener? {
        underlying.subscribe(toAblyCocoaCallback(callback))
    }

    internal func off(_ listener: EventListener) {
        underlying.off(listener)
    }
}

internal final class InternalRealtimeChannelsAdapter<Underlying: ProxyRealtimeChannelsProtocol>: InternalRealtimeChannelsProtocol {
    private let underlying: Underlying

    internal init(underlying: Underlying) {
        self.underlying = underlying
    }

    internal func get(_ name: String, options: RealtimeChannelOptions) -> InternalRealtimeChannelAdapter<Underlying.Channel> {
        let underlyingChannel = underlying.get(name, options: options)
        return InternalRealtimeChannelAdapter(underlying: underlyingChannel)
    }

    internal func release(_ name: String) {
        underlying.release(name)
    }
}

/// A version of `PresenceMessage` that uses strongly-typed `data` and `extras` properties. Only contains the properties that the Chat SDK is currently using; add as needed.
internal struct PresenceMessage {
    internal var clientId: String?
    internal var connectionID: String
    internal var timestamp: Date?
    internal var action: PresenceAction
    internal var data: JSONObject?
    internal var extras: [String: JSONValue]?
}

internal extension PresenceMessage {
    init(ablyCocoaPresenceMessage: AblyPubSubDevice.PresenceMessage) {
        clientId = ablyCocoaPresenceMessage.clientId
        connectionID = ablyCocoaPresenceMessage.connectionId
        timestamp = ablyCocoaPresenceMessage.timestamp
        action = ablyCocoaPresenceMessage.action
        if let ablyCocoaData = ablyCocoaPresenceMessage.data {
            data = JSONValue(ablyCocoaData: ablyCocoaData).objectValue
        }
        if let ablyCocoaExtras = ablyCocoaPresenceMessage.extras {
            extras = JSONValue.objectFromAblyCocoaExtras(ablyCocoaExtras)
        }
    }
}

/// A version of `Annotation` that uses strongly-typed `data` and `extras` properties. Only contains the properties that the Chat SDK is currently using; add as needed.
internal struct Annotation {
    internal var type: String?
    internal var count: Int?
    internal var clientId: String?
    internal var timestamp: Date?
    internal var action: AnnotationAction
    internal var data: JSONValue?
    internal var extras: [String: JSONValue]?
}

internal extension Annotation {
    init(ablyCocoaAnnotation: AblyPubSubDevice.Annotation) {
        type = ablyCocoaAnnotation.type
        count = ablyCocoaAnnotation.count?.intValue
        clientId = ablyCocoaAnnotation.clientId
        timestamp = ablyCocoaAnnotation.timestamp
        action = ablyCocoaAnnotation.action
        if let ablyCocoaData = ablyCocoaAnnotation.data {
            data = .init(ablyCocoaData: ablyCocoaData)
        }
        if let ablyCocoaExtras = ablyCocoaAnnotation.extras {
            extras = JSONValue.objectFromAblyCocoaExtras(ablyCocoaExtras)
        }
    }
}

/// A version of `ChannelStateChange` that uses our `ErrorInfo` type instead of `ErrorInfo`.
internal struct ChannelStateChange {
    internal var current: RealtimeChannelState
    internal var previous: RealtimeChannelState
    internal var event: ChannelEvent
    internal var reason: ErrorInfo?
    internal var resumed: Bool
}

internal extension ChannelStateChange {
    init(ablyCocoaChannelStateChange: AblyPubSubDevice.ChannelStateChange) {
        current = ablyCocoaChannelStateChange.current
        previous = ablyCocoaChannelStateChange.previous
        event = ablyCocoaChannelStateChange.event
        reason = .init(optionalAblyCocoaError: ablyCocoaChannelStateChange.reason)
        resumed = ablyCocoaChannelStateChange.resumed
    }
}

/// A version of `ConnectionStateChange` that uses our `ErrorInfo` type instead of `ErrorInfo`.
internal struct ConnectionStateChange {
    internal var current: RealtimeConnectionState
    internal var previous: RealtimeConnectionState
    internal var event: RealtimeConnectionEvent
    internal var reason: ErrorInfo?
    internal var retryIn: TimeInterval
}

internal extension ConnectionStateChange {
    init(ablyCocoaConnectionStateChange: AblyPubSubDevice.ConnectionStateChange) {
        current = ablyCocoaConnectionStateChange.current
        previous = ablyCocoaConnectionStateChange.previous
        event = ablyCocoaConnectionStateChange.event
        reason = .init(optionalAblyCocoaError: ablyCocoaConnectionStateChange.reason)
        retryIn = ablyCocoaConnectionStateChange.retryIn
    }
}
