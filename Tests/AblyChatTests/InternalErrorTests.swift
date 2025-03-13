import Ably
@testable import AblyChat
import Testing

struct InternalErrorTests {
    @Test
    func toARTErrorInfo_whenUnderlyingErrorIsARTErrorInfo() {
        let underlyingErrorInfo = ARTErrorInfo.createUnknownError()
        let internalError = InternalError.errorInfo(underlyingErrorInfo)

        let convertedToErrorInfo = internalError.toARTErrorInfo()
        #expect(convertedToErrorInfo === underlyingErrorInfo)
    }

    @Test
    func testToARTErrorInfo_whenUnderlyingErrorIsNotARTErrorInfo() {
        let internalError = InternalError.other(.chatAPIChatError(.noItemInResponse))

        let convertedToErrorInfo = internalError.toARTErrorInfo()
        #expect(isChatError(convertedToErrorInfo, withCodeAndStatusCode: .fixedStatusCode(.badRequest)))
        // Just check that there's _something_ in the error message that allows us to identify the underlying error
        #expect(convertedToErrorInfo.localizedDescription.contains("ChatAPI.ChatError.noItemInResponse"))
    }
}
