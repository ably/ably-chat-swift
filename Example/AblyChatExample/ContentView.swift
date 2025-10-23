import Ably
import AblyChat
import SwiftUI

private enum Environment: Equatable {
    // Set ``current`` to `.live` if you wish to connect to actual instances of the Chat client in either Prod or Sandbox environments. Setting the mode to `.mock` will use the `MockChatClient`, and therefore simulate all features of the Chat app.
    static let current: Self = .mock

    case mock
    /// - Parameters:
    ///   - key: Your Ably API key.
    ///   - clientId: A string that identifies this client.
    case live(key: String, clientID: String)

    @MainActor
    func createChatClient() -> any ChatClientProtocol {
        switch self {
        case .mock:
            return MockChatClient(
                clientOptions: ChatClientOptions(),
            )
        case let .live(key: key, clientID: clientID):
            let realtimeOptions = ARTClientOptions()
            realtimeOptions.key = key
            realtimeOptions.clientId = clientID
            let realtime = ARTRealtime(options: realtimeOptions)

            return ChatClient(realtime: realtime, clientOptions: .init())
        }
    }
}

struct ContentView: View {
    // Can be replaced with your own room name
    private let roomName = "DemoRoom"

    @State private var chatClient = Environment.current.createChatClient()
    @State private var room: (any Room)?
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Fetching room...")
                        .foregroundStyle(.secondary)
                }
            } else if let error {
                VStack(spacing: 16) {
                    Text("Failed to fetch room")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else if let room {
                RoomView(
                    room: room,
                    chatClient: chatClient,
                    roomName: roomName,
                )
            }
        }
        .task {
            do {
                isLoading = true
                room = try await chatClient.rooms.get(named: roomName, options: .init(occupancy: .init(enableEvents: true)))
                isLoading = false
            } catch {
                self.error = error
                isLoading = false
                print("Failed to fetch room: \(error)")
            }
        }
    }
}

#Preview {
    ContentView()
}
