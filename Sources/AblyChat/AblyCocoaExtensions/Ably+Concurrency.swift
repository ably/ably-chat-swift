import Ably

// This file contains extensions to ably-cocoa’s types, to make them easier to use in Swift concurrency.
// TODO: remove once we improve this experience in ably-cocoa (https://github.com/ably/ably-cocoa/issues/1967)

internal extension ARTRealtimeInstanceMethodsProtocol {
    func requestAsync(_ method: String, path: String, params: [String: String]?, body: Any?, headers: [String: String]?) async throws(ARTErrorInfo) -> ARTHTTPPaginatedResponse {
        try await withCheckedContinuation { (continuation: CheckedContinuation<Result<ARTHTTPPaginatedResponse, ARTErrorInfo>, _>) in
            do {
                try request(method, path: path, params: params, body: body, headers: headers) { response, error in
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
    }
}

internal extension ARTRealtimeChannelProtocol {
    func attachAsync() async throws(ARTErrorInfo) {
        try await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, ARTErrorInfo>, _>) in
            attach { error in
                if let error {
                    continuation.resume(returning: .failure(error))
                } else {
                    continuation.resume(returning: .success(()))
                }
            }
        }.get()
    }

    func detachAsync() async throws(ARTErrorInfo) {
        try await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, ARTErrorInfo>, _>) in
            detach { error in
                if let error {
                    continuation.resume(returning: .failure(error))
                } else {
                    continuation.resume(returning: .success(()))
                }
            }
        }.get()
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

internal extension ARTRealtimePresenceProtocol {
    func getAsync() async throws(ARTErrorInfo) -> [PresenceMessage] {
        try await withCheckedContinuation { (continuation: CheckedContinuation<Result<[PresenceMessage], ARTErrorInfo>, _>) in
            get { members, error in
                if let error {
                    continuation.resume(returning: .failure(error))
                } else if let members {
                    continuation.resume(returning: .success(members.map { .init(ablyCocoaPresenceMessage: $0) }))
                } else {
                    preconditionFailure("There is no error, so expected members")
                }
            }
        }.get()
    }

    func getAsync(_ query: ARTRealtimePresenceQuery) async throws(ARTErrorInfo) -> [PresenceMessage] {
        try await withCheckedContinuation { (continuation: CheckedContinuation<Result<[PresenceMessage], ARTErrorInfo>, _>) in
            get(query) { members, error in
                if let error {
                    continuation.resume(returning: .failure(error))
                } else if let members {
                    continuation.resume(returning: .success(members.map { .init(ablyCocoaPresenceMessage: $0) }))
                } else {
                    preconditionFailure("There is no error, so expected members")
                }
            }
        }.get()
    }

    func leaveAsync(_ data: JSONValue?) async throws(ARTErrorInfo) {
        try await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, ARTErrorInfo>, _>) in
            leave(data?.toAblyCocoaData) { error in
                if let error {
                    continuation.resume(returning: .failure(error))
                } else {
                    continuation.resume(returning: .success(()))
                }
            }
        }.get()
    }

    func enterClientAsync(_ clientID: String, data: JSONValue?) async throws(ARTErrorInfo) {
        try await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, ARTErrorInfo>, _>) in
            enterClient(clientID, data: data?.toAblyCocoaData) { error in
                if let error {
                    continuation.resume(returning: .failure(error))
                } else {
                    continuation.resume(returning: .success(()))
                }
            }
        }.get()
    }

    func updateAsync(_ data: JSONValue?) async throws(ARTErrorInfo) {
        try await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, ARTErrorInfo>, _>) in
            update(data?.toAblyCocoaData) { error in
                if let error {
                    continuation.resume(returning: .failure(error))
                } else {
                    continuation.resume(returning: .success(()))
                }
            }
        }.get()
    }
}
