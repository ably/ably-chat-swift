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
