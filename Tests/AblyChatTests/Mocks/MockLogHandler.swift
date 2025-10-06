import AblyChat

final class MockLogHandler: LogHandler.Simple, @unchecked Sendable {
    @SynchronizedAccess var logArguments: (message: String, level: LogLevel)?

    func log(message: String, level: LogLevel) {
        logArguments = (message: message, level: level)
    }
}
