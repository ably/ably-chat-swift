@testable import AblyChat
import Testing

struct DefaultRoomStatusTests {
    @Test
    func current_startsAsInitialized() async {
        let status = DefaultRoomStatus(logger: TestLogger())
        #expect(await status.current == .initialized)
    }

    @Test()
    func error_startsAsNil() async {
        let status = DefaultRoomStatus(logger: TestLogger())
        #expect(await status.error == nil)
    }

    @Test
    func transition() async throws {
        // Given: A DefaultRoomStatus
        let status = DefaultRoomStatus(logger: TestLogger())
        let originalState = await status.current
        let newState = RoomLifecycle.attached // arbitrary

        let subscription1 = await status.onChange(bufferingPolicy: .unbounded)
        let subscription2 = await status.onChange(bufferingPolicy: .unbounded)

        async let statusChange1 = subscription1.first { $0.current == newState }
        async let statusChange2 = subscription2.first { $0.current == newState }

        // When: transition(to:) is called
        await status.transition(to: newState)

        // Then: It emits a status change to all subscribers added via onChange(bufferingPolicy:), and updates its `current` property to the new state
        for statusChange in try await [#require(statusChange1), #require(statusChange2)] {
            #expect(statusChange.previous == originalState)
            #expect(statusChange.current == newState)
        }

        #expect(await status.current == .attached)
    }
}
