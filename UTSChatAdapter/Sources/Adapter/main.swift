import Foundation

func serve() async throws {
    let webSocket = await WebSocketWrapper()
    var adapter = await ChatAdapter(webSocket: webSocket)

    try await webSocket.start { message in
        do {
            let params = try message.json()
            print("RPC params: \(params)")

            let rpcResponse = try await adapter.handleRpcCall(rpcParams: params)
            try await webSocket.send(text: rpcResponse)
        } catch {
            print("Unhandled exception occured: \(error)") // TODO: replace with logger
        }
    }
}

do {
    try await serve()
} catch {
    print("Exiting due to fatal error: \(error)") // TODO: replace with logger
    exit(1)
}
