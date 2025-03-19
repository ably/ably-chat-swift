import Ably

/// The interface that the Chat SDK uses to access ably-cocoa's realtime functionality.
///
/// The idea is to translate ably-cocoa's `ARTRealtimeProtocol` interface into something that's more pleasant to use from Swift (and easier to mock), by using:
///
/// - `async` methods instead of callbacks
/// - typed throws
/// - `JSONValue` instead of `Any`
/// - `Sendable` types where helpful
/// - `AsyncSequence` where helpful
///
/// Note that the API of this protocol is not currently consistent; for example there are some places in the codebase where we subscribe to Realtime channel state using callbacks, and other places where we subscribe using `AsyncSequence`. We should aim to make this consistent; see https://github.com/ably/ably-chat-swift/issues/245.
///
/// Hopefully we will eventually be able to remove this interface once we've improved the experience of using ably-cocoa from Swift (https://github.com/ably/ably-cocoa/issues/1967).
///
/// This protocol only contains the functionality from ably-cocoa that we're actually currently using in the Chat SDK, so you might need to add new properties and methods to it over time.
///
/// The default implementation of this protocol is ``InternalRealtimeClientAdapter``, which uses an underlying ably-cocoa `ARTRealtimeProtocol` object.
internal protocol InternalRealtimeClientProtocol: AnyObject, Sendable {
    associatedtype Channels: InternalRealtimeChannelsProtocol
    associatedtype Connection: InternalConnectionProtocol

    var clientId: String? { get }
    func request(_ method: String, path: String, params: [String: String]?, body: Any?, headers: [String: String]?) async throws(InternalError) -> ARTHTTPPaginatedResponse

    var channels: Channels { get }
    var connection: Connection { get }
}

/// Expresses the requirements of the object returned by ``InternalRealtimeClientProtocol/channels``.
internal protocol InternalRealtimeChannelsProtocol: AnyObject, Sendable {
    associatedtype Channel: InternalRealtimeChannelProtocol

    func get(_ name: String, options: ARTRealtimeChannelOptions) -> Channel

    func release(_ name: String)
}

/// Expresses the requirements of the object returned by ``InternalRealtimeChannelsProtocol/get(_:options:)``.
internal protocol InternalRealtimeChannelProtocol: AnyObject, Sendable {
    associatedtype Presence: InternalRealtimePresenceProtocol

    /// The ably-cocoa realtime channel that this channel wraps.
    ///
    /// We need to be able to access this so that we can return it from the `channel` methods in the SDK's public API, which allow users of the SDK to access the realtime channels that the SDK uses.
    var underlying: any RealtimeChannelProtocol { get }

    var presence: Presence { get }

    func attach() async throws(InternalError)
    func detach() async throws(InternalError)
    var name: String { get }
    var state: ARTRealtimeChannelState { get }
    var errorReason: ARTErrorInfo? { get }
    func on(_ cb: @escaping (ARTChannelStateChange) -> Void) -> ARTEventListener
    func on(_ event: ARTChannelEvent, callback cb: @escaping (ARTChannelStateChange) -> Void) -> ARTEventListener
    func unsubscribe(_: ARTEventListener?)
    func publish(_ name: String?, data: JSONValue?, extras: [String: JSONValue]?) async throws(InternalError)
    func subscribe(_ name: String, callback: @escaping ARTMessageCallback) -> ARTEventListener?
    var properties: ARTChannelProperties { get }
    func off(_ listener: ARTEventListener)
}

/// Expresses the requirements of the object returned by ``InternalRealtimeChannelProtocol/presence``.
internal protocol InternalRealtimePresenceProtocol: AnyObject, Sendable {
    func get() async throws(InternalError) -> [PresenceMessage]
    func get(_ query: ARTRealtimePresenceQuery) async throws(InternalError) -> [PresenceMessage]
    func leave(_ data: JSONValue?) async throws(InternalError)
    func enterClient(_ clientID: String, data: JSONValue?) async throws(InternalError)
    func update(_ data: JSONValue?) async throws(InternalError)
    func subscribe(_ callback: @escaping ARTPresenceMessageCallback) -> ARTEventListener?
    func subscribe(_ action: ARTPresenceAction, callback: @escaping ARTPresenceMessageCallback) -> ARTEventListener?
    func unsubscribe(_ listener: ARTEventListener)
    func leaveClient(_ clientId: String, data: JSONValue?) async throws(InternalError)
}

/// Expresses the requirements of the object returned by ``InternalRealtimeClientProtocol/connection``.
internal protocol InternalConnectionProtocol: AnyObject, Sendable {
    var state: ARTRealtimeConnectionState { get }
    var errorReason: ARTErrorInfo? { get }

    func on(_ cb: @escaping (ARTConnectionStateChange) -> Void) -> ARTEventListener
    func off(_ listener: ARTEventListener)
}

internal final class InternalRealtimeClientAdapter: InternalRealtimeClientProtocol {
    private let underlying: RealtimeClient
    internal let channels: Channels
    internal let connection: Connection

    internal init(underlying: RealtimeClient) {
        self.underlying = underlying
        channels = .init(underlying: underlying.channels)
        connection = .init(underlying: underlying.connection)
    }

    internal var clientId: String? {
        underlying.clientId
    }

    internal func request(_ method: String, path: String, params: [String: String]?, body: Any?, headers: [String: String]?) async throws(InternalError) -> ARTHTTPPaginatedResponse {
        do {
            return try await withCheckedContinuation { (continuation: CheckedContinuation<Result<ARTHTTPPaginatedResponse, ARTErrorInfo>, _>) in
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
                    // This is a weird bit of API design in ably-cocoa (see https://github.com/ably/ably-cocoa/issues/2043 for fixing it); it throws an error to indicate a programmer error (it should be using exceptions). Since the type of the thrown error is NSError and not ARTErrorInfo, which would mess up our typed throw, let's not try and propagate it.
                    fatalError("ably-cocoa request threw an error - this indicates a programmer error")
                }
            }.get()
        } catch {
            throw error.toInternalError()
        }
    }

    internal final class Channels: InternalRealtimeChannelsProtocol {
        private let underlying: any RealtimeChannelsProtocol

        internal init(underlying: any RealtimeChannelsProtocol) {
            self.underlying = underlying
        }

        internal func get(_ name: String, options: ARTRealtimeChannelOptions) -> some InternalRealtimeChannelProtocol {
            let underlyingChannel = underlying.get(name, options: options)
            return InternalRealtimeClientAdapter.Channel(underlying: underlyingChannel)
        }

        internal func release(_ name: String) {
            underlying.release(name)
        }
    }

    internal final class Channel: InternalRealtimeChannelProtocol {
        internal let underlying: any RealtimeChannelProtocol
        internal let presence: InternalRealtimeClientAdapter.Presence

        internal init(underlying: any RealtimeChannelProtocol) {
            self.underlying = underlying
            presence = .init(underlying: underlying.presence)
        }

        internal var name: String {
            underlying.name
        }

        internal var state: ARTRealtimeChannelState {
            underlying.state
        }

        internal var errorReason: ARTErrorInfo? {
            underlying.errorReason
        }

        internal var properties: ARTChannelProperties {
            underlying.properties
        }

        internal func attach() async throws(InternalError) {
            do {
                try await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, ARTErrorInfo>, _>) in
                    underlying.attach { error in
                        if let error {
                            continuation.resume(returning: .failure(error))
                        } else {
                            continuation.resume(returning: .success(()))
                        }
                    }
                }.get()
            } catch {
                throw error.toInternalError()
            }
        }

        internal func detach() async throws(InternalError) {
            do {
                try await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, ARTErrorInfo>, _>) in
                    underlying.detach { error in
                        if let error {
                            continuation.resume(returning: .failure(error))
                        } else {
                            continuation.resume(returning: .success(()))
                        }
                    }
                }.get()
            } catch {
                throw error.toInternalError()
            }
        }

        internal func publish(_ name: String?, data: JSONValue?, extras: [String: JSONValue]?) async throws(InternalError) {
            do {
                try await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, ARTErrorInfo>, _>) in
                    underlying.publish(name, data: data?.toAblyCocoaData, extras: extras?.toARTJsonCompatible) { error in
                        if let error {
                            continuation.resume(returning: .failure(error))
                        } else {
                            continuation.resume(returning: .success(()))
                        }
                    }
                }.get()
            } catch {
                throw error.toInternalError()
            }
        }

        internal func on(_ cb: @escaping (ARTChannelStateChange) -> Void) -> ARTEventListener {
            underlying.on(cb)
        }

        internal func on(_ event: ARTChannelEvent, callback cb: @escaping (ARTChannelStateChange) -> Void) -> ARTEventListener {
            underlying.on(event, callback: cb)
        }

        internal func unsubscribe(_ listener: ARTEventListener?) {
            underlying.unsubscribe(listener)
        }

        internal func publish(_ name: String?, data: Any?, extras: (any ARTJsonCompatible)?) {
            underlying.publish(name, data: data, extras: extras)
        }

        internal func subscribe(_ name: String, callback: @escaping ARTMessageCallback) -> ARTEventListener? {
            underlying.subscribe(name, callback: callback)
        }

        internal func off(_ listener: ARTEventListener) {
            underlying.off(listener)
        }
    }

    internal final class Presence: InternalRealtimePresenceProtocol {
        private let underlying: any RealtimePresenceProtocol

        internal init(underlying: any RealtimePresenceProtocol) {
            self.underlying = underlying
        }

        internal func get() async throws(InternalError) -> [PresenceMessage] {
            do {
                return try await withCheckedContinuation { (continuation: CheckedContinuation<Result<[PresenceMessage], ARTErrorInfo>, _>) in
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
                throw error.toInternalError()
            }
        }

        internal func get(_ query: ARTRealtimePresenceQuery) async throws(InternalError) -> [PresenceMessage] {
            do {
                return try await withCheckedContinuation { (continuation: CheckedContinuation<Result<[PresenceMessage], ARTErrorInfo>, _>) in
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
                throw error.toInternalError()
            }
        }

        internal func leave(_ data: JSONValue?) async throws(InternalError) {
            do {
                try await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, ARTErrorInfo>, _>) in
                    underlying.leave(data?.toAblyCocoaData) { error in
                        if let error {
                            continuation.resume(returning: .failure(error))
                        } else {
                            continuation.resume(returning: .success(()))
                        }
                    }
                }.get()
            } catch {
                throw error.toInternalError()
            }
        }

        internal func enterClient(_ clientID: String, data: JSONValue?) async throws(InternalError) {
            do {
                try await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, ARTErrorInfo>, _>) in
                    underlying.enterClient(clientID, data: data?.toAblyCocoaData) { error in
                        if let error {
                            continuation.resume(returning: .failure(error))
                        } else {
                            continuation.resume(returning: .success(()))
                        }
                    }
                }.get()
            } catch {
                throw error.toInternalError()
            }
        }

        internal func update(_ data: JSONValue?) async throws(InternalError) {
            do {
                try await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, ARTErrorInfo>, _>) in
                    underlying.update(data?.toAblyCocoaData) { error in
                        if let error {
                            continuation.resume(returning: .failure(error))
                        } else {
                            continuation.resume(returning: .success(()))
                        }
                    }
                }.get()
            } catch {
                throw error.toInternalError()
            }
        }

        internal func subscribe(_ callback: @escaping ARTPresenceMessageCallback) -> ARTEventListener? {
            underlying.subscribe(callback)
        }

        internal func subscribe(_ action: ARTPresenceAction, callback: @escaping ARTPresenceMessageCallback) -> ARTEventListener? {
            underlying.subscribe(action, callback: callback)
        }

        internal func unsubscribe(_ listener: ARTEventListener) {
            underlying.unsubscribe(listener)
        }

        internal func leaveClient(_ clientID: String, data: JSONValue?) async throws(InternalError) {
            do {
                try await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, ARTErrorInfo>, _>) in
                    underlying.leaveClient(clientID, data: data?.toAblyCocoaData) { error in
                        if let error {
                            continuation.resume(returning: .failure(error))
                        } else {
                            continuation.resume(returning: .success(()))
                        }
                    }
                }.get()
            } catch {
                throw error.toInternalError()
            }
        }
    }

    internal final class Connection: InternalConnectionProtocol {
        private let underlying: any ConnectionProtocol

        internal init(underlying: any ConnectionProtocol) {
            self.underlying = underlying
        }

        internal var state: ARTRealtimeConnectionState {
            underlying.state
        }

        internal var errorReason: ARTErrorInfo? {
            underlying.errorReason
        }

        internal func on(_ cb: @escaping (ARTConnectionStateChange) -> Void) -> ARTEventListener {
            underlying.on(cb)
        }

        internal func off(_ listener: ARTEventListener) {
            underlying.off(listener)
        }
    }
}

/// A `Sendable` version of `ARTPresenceMessage`. Only contains the properties that the Chat SDK is currently using; add as needed.
internal struct PresenceMessage {
    internal var clientId: String?
    internal var timestamp: Date?
    internal var action: ARTPresenceAction
    internal var data: JSONValue?
    internal var extras: [String: JSONValue]?
}

internal extension PresenceMessage {
    init(ablyCocoaPresenceMessage: ARTPresenceMessage) {
        clientId = ablyCocoaPresenceMessage.clientId
        timestamp = ablyCocoaPresenceMessage.timestamp
        action = ablyCocoaPresenceMessage.action
        if let ablyCocoaData = ablyCocoaPresenceMessage.data {
            data = .init(ablyCocoaData: ablyCocoaData)
        }
        if let ablyCocoaExtras = ablyCocoaPresenceMessage.extras {
            extras = JSONValue.objectFromAblyCocoaExtras(ablyCocoaExtras)
        }
    }
}
