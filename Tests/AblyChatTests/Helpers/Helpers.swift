import Ably
@testable import AblyChat
import XCTest

/**
 Asserts that a given optional `Error` is an `ARTErrorInfo` in the chat error domain with a given code.
 */
func assertIsChatError(_ maybeError: (any Error)?, withCode code: AblyChat.ErrorCode, cause: ARTErrorInfo? = nil, file: StaticString = #filePath, line: UInt = #line) throws {
    let error = try XCTUnwrap(maybeError, "Expected an error", file: file, line: line)
    let ablyError = try XCTUnwrap(error as? ARTErrorInfo, "Expected an ARTErrorInfo", file: file, line: line)

    XCTAssertEqual(ablyError.domain, AblyChat.errorDomain as String, file: file, line: line)
    XCTAssertEqual(ablyError.code, code.rawValue, file: file, line: line)
    XCTAssertEqual(ablyError.statusCode, code.statusCode, file: file, line: line)
    XCTAssertEqual(ablyError.cause, cause, file: file, line: line)
}

/**
 Asserts that a given async expression throws an `ARTErrorInfo` in the chat error domain with a given code.

 Doesn't take an autoclosure because for whatever reason one of our linting tools removes the `await` on the expression.
 */
func assertThrowsARTErrorInfo(withCode code: AblyChat.ErrorCode, cause: ARTErrorInfo? = nil, _ expression: () async throws -> some Any, file: StaticString = #filePath, line: UInt = #line) async throws {
    let caughtError: Error?

    do {
        _ = try await expression()
        caughtError = nil
    } catch {
        caughtError = error
    }

    try assertIsChatError(caughtError, withCode: code, cause: cause, file: file, line: line)
}
