import Foundation

@MainActor
final class WebSocketWrapper: NSObject, URLSessionWebSocketDelegate {
    private var webSocket: URLSessionWebSocketTask!

    func start(onMessage: @escaping (URLSessionWebSocketTask.Message) async throws -> Void) async throws {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .current)
        let url = URL(string: "ws://localhost:3000")!

        webSocket = session.webSocketTask(with: url)
        webSocket.resume()

        while !Task.isCancelled {
            do {
                try await onMessage(webSocket.receive())
            } catch {
                print("Can't connect to \(url): \(error.localizedDescription)")
                sleep(5) // try again in 5 seconds
                webSocket = session.webSocketTask(with: url) // without recreating the task it doesn't work
                webSocket.resume()
            }
        }
    }

    func send(text: String) async throws {
        print("Sending: \(text)")
        try await webSocket.send(URLSessionWebSocketTask.Message.string(text))
    }

    // MARK: URLSessionWebSocketDelegate

    nonisolated func urlSession(_: URLSession, webSocketTask _: URLSessionWebSocketTask, didOpenWithProtocol _: String?) {
        print("Connected to server")
        Task {
            try await send(text: "{\"role\":\"ADAPTER\"}")
        }
    }

    nonisolated func urlSession(_: URLSession, webSocketTask _: URLSessionWebSocketTask, didCloseWith _: URLSessionWebSocketTask.CloseCode, reason _: Data?) {
        print("Disconnected from server")
    }
}
