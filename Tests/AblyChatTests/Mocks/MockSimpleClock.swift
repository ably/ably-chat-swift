@testable import AblyChat

actor MockSimpleClock: SimpleClock {
    private(set) var sleepCallArguments: [UInt64] = []

    func sleep(nanoseconds duration: UInt64) async throws {
        sleepCallArguments.append(duration)
    }
}
