@testable import AblyChat

struct TestLogger: InternalLogger {
    func log(message: String, level _: LogLevel, codeLocation _: CodeLocation) {
        // No-op; currently we don’t log in tests to keep the test logs easy to read. Can reconsider if necessary.
        print(message)
    }
}
