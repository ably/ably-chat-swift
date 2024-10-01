@testable import AblyChat
import Foundation

/// A mock implementation of ``SimpleClock`` which records its arguments but does not actually sleep.
actor MockSimpleClock: SimpleClock {
    private(set) var sleepCallArguments: [TimeInterval] = []

    func sleep(timeInterval: TimeInterval) async throws {
        sleepCallArguments.append(timeInterval)
    }
}
