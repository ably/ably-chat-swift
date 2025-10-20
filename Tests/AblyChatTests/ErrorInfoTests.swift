import Ably
@testable import AblyChat
import Testing

struct ErrorInfoTests {
    @Test
    func whenUnderlyingErrorIsAblyCocoaError() {
        // Given: An ErrorInfo based on an ably-cocoa error

        // Note: The facts that ARTErrorInfoStatusCode populates `statusCode`, that NSUnderlyingErrorKey populates `cause`, and that NSLocalizedDescriptionKey populates `message` are implementation details of ably-cocoa that we rely on in this test (but not in our implementation of ErrorInfo).

        let ablyCocoaCause = ARTErrorInfo(
            domain: "SomeDomain", // irrelevant
            code: 52000,
            userInfo: [
                "ARTErrorInfoStatusCode": 520,
                NSLocalizedDescriptionKey: "This made the bad thing happen.",
            ],
        )

        let ablyCocoaError = ARTErrorInfo(
            domain: "SomeOtherDomain", // irrelevant
            code: 41000,
            userInfo: [
                "ARTErrorInfoStatusCode": 410,
                NSLocalizedDescriptionKey: "A bad thing happened.",
                NSUnderlyingErrorKey: ablyCocoaCause,
            ],
        )

        let errorInfo = ErrorInfo(ablyCocoaError: ablyCocoaError)

        // Then: The properties are just passed through from the ably-cocoa error
        #expect(
            errorInfo == .init(
                code: 41000,
                // Note re this href property and the one below: it seems ably-cocoa is incorrectly populating these; my interpretation of TI4 is that they should only be populated when received in a REST response.
                href: "https://help.ably.io/error/410",
                message: "A bad thing happened.",
                cause: .init(
                    code: 52000,
                    href: "https://help.ably.io/error/520",
                    message: "This made the bad thing happen.",
                    statusCode: 520,
                ),
                statusCode: 410,
            ),
        )
    }

    @Test
    func whenUnderlyingErrorIsNotAblyCocoaError() {
        let internalError = InternalError.other(.chatAPIChatError(.noItemInResponse))

        let convertedToErrorInfo = internalError.toErrorInfo()

        #expect(convertedToErrorInfo.hasCodeAndStatusCode(.fixedStatusCode(.badRequest)))
        // Just check that there's _something_ in the error message that allows us to identify the underlying error
        for message in [convertedToErrorInfo.message, convertedToErrorInfo.description, convertedToErrorInfo.localizedDescription] {
            #expect(message.contains("ChatAPI.ChatError.noItemInResponse"))
        }
    }
}
