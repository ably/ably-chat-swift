@testable import AblyChat
import Testing

struct DefaultInternalLoggerTests {
    @Test
    func defaults() {
        let logger = DefaultInternalLogger(logHandler: nil, logLevel: nil)

        #expect(logger.testsOnly_logHandler is DefaultLogHandler)
        #expect(logger.testsOnly_logLevel == .error)
    }

    @Test
    func log() throws {
        // Given: A DefaultInternalLogger instance
        let logHandler = MockLogHandler()
        let logger = DefaultInternalLogger(logHandler: logHandler, logLevel: nil)

        // When: `log(message:level:codeLocation:)` is called on it
        logger.log(
            message: "Hello",
            level: .error, // arbitrary
            codeLocation: .init(fileID: "Ably/Room.swift", line: 123),
        )

        // Then: It calls log(…) on the underlying logger, interpolating the code location into the message and passing through the level
        let logArguments = try #require(logHandler.logArguments)
        #expect(logArguments.message == "(Ably/Room.swift:123) Hello")
        #expect(logArguments.level == .error)
        #expect(logArguments.context == nil)
    }

    @Test
    func log_whenLogLevelArgumentIsLessSevereThanLogLevelProperty_itDoesNotLog() {
        // Given: A DefaultInternalLogger instance
        let logHandler = MockLogHandler()
        let logger = DefaultInternalLogger(
            logHandler: logHandler,
            logLevel: .info, // arbitrary
        )

        // When: `log(message:level:codeLocation:)` is called on it, with `level` less severe than that of the instance
        logger.log(
            message: "Hello",
            level: .debug,
            codeLocation: .init(fileID: "", line: 0),
        )

        // Then: It does not call `log(…)` on the underlying logger
        #expect(logHandler.logArguments == nil)
    }
}
