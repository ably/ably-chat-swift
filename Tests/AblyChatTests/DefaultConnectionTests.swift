import Ably
@testable import AblyChat
import Testing

@MainActor
struct DefaultConnectionTests {
    // MARK: - CHA-CS1: Connection Status Values

    // These specs are not marked as `[Testable]`, but lets have this basic check anyway:
    // CHA-CS1a
    // CHA-CS1b
    // CHA-CS1c
    // CHA-CS1d
    // CHA-CS1e
    // CHA-CS1f
    // CHA-CS1g
    // CHA-CS1h
    @Test
    func chatConnectionStatusReflectsAllRealtimeConnectionStates() async throws {
        // Test all possible realtime connection state mappings to chat connection status
        let testCases: [(ARTRealtimeConnectionState, ConnectionStatus, String)] = [
            // CHA-CS1a: INITIALIZED status
            (.initialized, .initialized, "initialized"),
            // CHA-CS1b: CONNECTING status
            (.connecting, .connecting, "connecting"),
            // CHA-CS1c: CONNECTED status
            (.connected, .connected, "connected"),
            // CHA-CS1d: DISCONNECTED status
            (.disconnected, .disconnected, "disconnected"),
            // CHA-CS1e: SUSPENDED status
            (.suspended, .suspended, "suspended"),
            // CHA-CS1f: FAILED status
            (.failed, .failed, "failed"),
            // CHA-CS1g: CLOSING status
            (.closing, .closing, "closing"),
            // CHA-CS1h: CLOSED status
            (.closed, .closed, "closed"),
        ]

        for (realtimeState, expectedChatStatus, description) in testCases {
            // Given: A connection in a specific realtime state
            let mockConnection = MockConnection(state: realtimeState)
            let mockRealtime = MockRealtime(connection: mockConnection)
            let connection = DefaultConnection(realtime: mockRealtime)

            // When: The connection status is checked
            let status = connection.status

            // Then: Status should match the expected chat connection status
            #expect(status == expectedChatStatus, "Realtime state \(description) should map to \(expectedChatStatus)")
        }
    }

    // MARK: - CHA-CS2: Exposing Connection Status and Error

    // @spec CHA-CS2a
    // @spec CHA-CS2b
    // @spec CHA-CS3
    @Test
    func chatClientMustExposeItsCurrentStatusAndError() async throws {
        // Given: An instance of ChatClient with initialized connection and no error
        let options = ARTClientOptions(key: "fake:key")
        options.autoConnect = false
        let realtime = ARTRealtime(options: options)
        let client = ChatClient(realtime: realtime, clientOptions: nil)

        // When: The connection status and error are checked
        let status = client.connection.status
        let error = client.connection.error

        // Then: Status should be initialized and error should be nil (CHA-CS3)
        #expect(status == .initialized)
        #expect(error == nil)
    }

    // @spec CHA-CS2b
    @Test
    func chatClientMustExposeLatestError() async throws {
        // Given: A connection with an error
        let connectionError = ErrorInfo(
            code: 40142,
            message: "Connection failed",
            statusCode: 401,
        )
        let mockConnection = MockConnection(state: .failed, errorReason: connectionError)
        let mockRealtime = MockRealtime(connection: mockConnection)
        let connection = DefaultConnection(realtime: mockRealtime)

        // When: The error is checked
        let error = connection.error

        // Then: The error should match the connection error
        #expect(error?.code == connectionError.code)
        #expect(error?.message == connectionError.message)
        #expect(error?.statusCode == connectionError.statusCode)
    }

    // MARK: - CHA-CS4: Observing Connection Status

    // @spec CHA-CS4a
    // @spec CHA-CS4b
    // @spec CHA-CS4c
    // @spec CHA-CS4d
    // @spec CHA-CS4e
    // @spec CHA-CS5c - mocks are the same as for CHA-CS4, so CHA-CS5c is covered by this test
    @Test
    func clientsCanRegisterListenerForConnectionStatusEvents() async throws {
        // Given: A connection and a listener
        let mockConnection = MockConnection(state: .connecting)
        let mockRealtime = MockRealtime(connection: mockConnection)
        let connection = DefaultConnection(realtime: mockRealtime)
        let connectionError = ErrorInfo(
            code: 80003,
            message: "Connection lost",
            statusCode: 500,
        )

        var receivedStatusChanges: [ConnectionStatusChange] = []

        // When: Register a listener (CHA-CS4d)
        let subscription = connection.onStatusChange { statusChange in
            receivedStatusChanges.append(statusChange)
        }

        // And: Emit a state change
        mockConnection.emit(.disconnected, event: .disconnected, error: connectionError)

        // Then: The listener should receive the event with correct information
        #expect(receivedStatusChanges.count == 1)

        let statusChange = receivedStatusChanges[0]
        // (CHA-CS4a) Contains newly entered connection status
        #expect(statusChange.current == .disconnected)
        // (CHA-CS4b) Contains previous connection status
        #expect(statusChange.previous == .connecting)
        // (CHA-CS4c) Contains connection error
        #expect(statusChange.error?.code == connectionError.code)
        #expect(statusChange.error?.message == connectionError.message)

        // When: Unregister the listener (CHA-CS4e)
        subscription.off()
        receivedStatusChanges.removeAll()

        // And: Emit a state change
        mockConnection.emit(.disconnected, event: .disconnected)

        // Then: The listener should not receive any events
        #expect(receivedStatusChanges.isEmpty)
    }
}
