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
                // TODO: this needs sorting out in ably-cocoa
                let ablyError = error as! ARTErrorInfo
                continuation.resume(returning: .failure(ablyError))
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

// TODO: explain (value type so that we can return from getAsync, and also we map to our nice internal types) this is just a subset too
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
            leave(data?.toAblyCocoaData) { error in
                if let error {
                    continuation.resume(returning: .failure(error))
                } else {
                    continuation.resume(returning: .success(()))
                }
            }
        }.get()
    }
}
