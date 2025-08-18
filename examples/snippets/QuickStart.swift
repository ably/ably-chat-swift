//
//  QuickStart.swift
//  Ably Chat Swift SDK Examples
//
//  Complete minimal example showing basic chat setup and message sending
//  This example demonstrates the quickest way to get started with Ably Chat
//

import AblyChat
import Ably
import Foundation

// MARK: - Quick Start Example

/// A minimal chat implementation that demonstrates basic setup and messaging
class QuickStartChat {
    private var chatClient: ChatClient?
    private var room: Room?
    
    /// Initialize the chat client with your Ably API key
    /// - Parameter apiKey: Your Ably API key from the dashboard
    func initializeChat(apiKey: String, clientId: String) async throws {
        // 1. Create Ably Realtime client with your API key
        let options = ARTClientOptions(key: apiKey)
        options.clientId = clientId
        
        let realtimeClient = ARTRealtime(options: options)
        
        // 2. Create Chat client from the Realtime client
        chatClient = DefaultChatClient(
            realtime: realtimeClient,
            clientOptions: ChatClientOptions()
        )
    }
    
    /// Get or create a chat room
    /// - Parameter roomName: The unique name for the chat room
    func getRoom(named roomName: String) async throws -> Room {
        guard let chatClient = chatClient else {
            throw NSError(domain: "QuickStartError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Chat client not initialized"])
        }
        
        // Get room with default options
        room = try await chatClient.rooms.get(roomName: roomName, options: RoomOptions())
        
        // Attach to the room to start receiving events
        try await room!.attach()
        
        return room!
    }
    
    /// Send a simple text message to the room
    /// - Parameter text: The message text to send
    func sendMessage(text: String) async throws {
        guard let room = room else {
            throw NSError(domain: "QuickStartError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Room not initialized"])
        }
        
        // Send message with just text
        let params = SendMessageParams(text: text)
        let sentMessage = try await room.messages.send(params: params)
        
        print("✅ Message sent: \(sentMessage.text)")
    }
    
    /// Subscribe to incoming messages
    func subscribeToMessages() async throws {
        guard let room = room else {
            throw NSError(domain: "QuickStartError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Room not initialized"])
        }
        
        // Subscribe to new messages using callback approach
        room.messages.subscribe { messageEvent in
            print("📨 Received message: \(messageEvent.message.text)")
            print("   From: \(messageEvent.message.clientID)")
            print("   At: \(messageEvent.message.createdAt?.description ?? "Unknown")")
        }
    }
    
    /// Subscribe to messages using AsyncSequence (modern Swift approach)
    func subscribeToMessagesAsync() async throws {
        guard let room = room else {
            throw NSError(domain: "QuickStartError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Room not initialized"])
        }
        
        // Subscribe using AsyncSequence
        let messageSubscription = room.messages.subscribe()
        
        // Handle messages in background task
        Task {
            for await messageEvent in messageSubscription {
                await MainActor.run {
                    print("📨 Async message: \(messageEvent.message.text)")
                    print("   From: \(messageEvent.message.clientID)")
                }
            }
        }
    }
    
    /// Clean up resources
    func cleanup() async throws {
        try await room?.detach()
        room = nil
        chatClient = nil
    }
}

// MARK: - Usage Example

/// Example usage of the QuickStartChat class
func quickStartExample() async {
    let chat = QuickStartChat()
    
    do {
        // 1. Initialize chat with your API key
        try await chat.initializeChat(
            apiKey: "YOUR_ABLY_API_KEY",
            clientId: "user123"
        )
        
        // 2. Get a room
        let room = try await chat.getRoom(named: "general")
        print("✅ Connected to room: \(room.name)")
        
        // 3. Subscribe to messages
        try await chat.subscribeToMessages()
        
        // 4. Send a welcome message
        try await chat.sendMessage(text: "Hello, Ably Chat! 👋")
        
        // 5. Send a message with emoji
        try await chat.sendMessage(text: "This is my first message 🎉")
        
        // Keep the example running for a bit to receive messages
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        
        // 6. Cleanup
        try await chat.cleanup()
        print("✅ Chat cleanup completed")
        
    } catch {
        print("❌ Error in quick start: \(error)")
    }
}

// MARK: - Alternative Initialization Patterns

/// Alternative ways to initialize the Chat client
class AlternativeInitialization {
    
    /// Initialize with token authentication
    static func initializeWithToken(token: String, clientId: String) -> ChatClient {
        let options = ARTClientOptions()
        options.token = token
        options.clientId = clientId
        
        let realtimeClient = ARTRealtime(options: options)
        
        return DefaultChatClient(
            realtime: realtimeClient,
            clientOptions: ChatClientOptions()
        )
    }
    
    /// Initialize with custom client options and logging
    static func initializeWithCustomOptions(apiKey: String, clientId: String) -> ChatClient {
        let options = ARTClientOptions(key: apiKey)
        options.clientId = clientId
        
        let realtimeClient = ARTRealtime(options: options)
        
        // Custom chat client options with logging
        let chatOptions = ChatClientOptions(
            logHandler: DefaultLogHandler(),
            logLevel: .info
        )
        
        return DefaultChatClient(
            realtime: realtimeClient,
            clientOptions: chatOptions
        )
    }
    
    /// Initialize with environment detection
    static func initializeWithEnvironment(
        apiKey: String, 
        clientId: String, 
        environment: String = "sandbox"
    ) -> ChatClient {
        let options = ARTClientOptions(key: apiKey)
        options.clientId = clientId
        options.environment = environment
        
        let realtimeClient = ARTRealtime(options: options)
        
        return DefaultChatClient(
            realtime: realtimeClient,
            clientOptions: ChatClientOptions()
        )
    }
}

// MARK: - Basic Room Configuration

/// Examples of different room configurations
class RoomConfigurationExamples {
    
    /// Get room with custom options
    static func getRoomWithCustomOptions(
        chatClient: ChatClient, 
        roomName: String
    ) async throws -> Room {
        
        // Configure room options
        let roomOptions = RoomOptions(
            messages: MessagesOptions(
                rawMessageReactions: true,  // Enable raw reaction events
                defaultMessageReactionType: .distinct
            ),
            presence: PresenceOptions(
                enableEvents: true  // Enable presence events
            ),
            typing: TypingOptions(
                heartbeatThrottle: 10  // 10 second throttle for typing
            ),
            reactions: RoomReactionsOptions(),
            occupancy: OccupancyOptions(
                enableEvents: true  // Enable occupancy events
            )
        )
        
        return try await chatClient.rooms.get(roomName: roomName, options: roomOptions)
    }
    
    /// Get room with minimal configuration (messages only)
    static func getMessagesOnlyRoom(
        chatClient: ChatClient, 
        roomName: String
    ) async throws -> Room {
        
        let roomOptions = RoomOptions(
            presence: PresenceOptions(enableEvents: false),
            typing: TypingOptions(),
            reactions: RoomReactionsOptions(),
            occupancy: OccupancyOptions(enableEvents: false)
        )
        
        return try await chatClient.rooms.get(roomName: roomName, options: roomOptions)
    }
}

// MARK: - Message Sending Patterns

/// Different ways to send messages
extension QuickStartChat {
    
    /// Send message with metadata
    func sendMessageWithMetadata(text: String, metadata: [String: Any]) async throws {
        guard let room = room else { return }
        
        let params = SendMessageParams(
            text: text,
            metadata: metadata
        )
        
        let message = try await room.messages.send(params: params)
        print("✅ Message with metadata sent: \(message.serial)")
    }
    
    /// Send message with headers (for filtering)
    func sendMessageWithHeaders(text: String, headers: [String: String]) async throws {
        guard let room = room else { return }
        
        let params = SendMessageParams(
            text: text,
            headers: headers
        )
        
        let message = try await room.messages.send(params: params)
        print("✅ Message with headers sent: \(message.serial)")
    }
    
    /// Send rich message with both metadata and headers
    func sendRichMessage(
        text: String,
        metadata: [String: Any],
        headers: [String: String]
    ) async throws {
        guard let room = room else { return }
        
        let params = SendMessageParams(
            text: text,
            metadata: metadata,
            headers: headers
        )
        
        let message = try await room.messages.send(params: params)
        print("✅ Rich message sent: \(message.serial)")
    }
}

// MARK: - Complete Working Example

/// A complete working example that demonstrates all basic functionality
@MainActor
class CompleteQuickStartExample {
    private let chat = QuickStartChat()
    
    func runExample() async {
        do {
            print("🚀 Starting Ably Chat Quick Start Example")
            
            // Initialize
            try await chat.initializeChat(
                apiKey: "YOUR_ABLY_API_KEY",
                clientId: "quickstart-user-\(UUID().uuidString.prefix(8))"
            )
            
            // Get room and attach
            let room = try await chat.getRoom(named: "quickstart-demo")
            print("✅ Connected to room: \(room.name)")
            
            // Subscribe to messages
            try await chat.subscribeToMessages()
            print("✅ Subscribed to messages")
            
            // Send various types of messages
            try await chat.sendMessage(text: "Hello from Quick Start! 👋")
            
            try await chat.sendMessageWithMetadata(
                text: "Message with metadata",
                metadata: ["type": "greeting", "priority": "high"]
            )
            
            try await chat.sendMessageWithHeaders(
                text: "Message with headers",
                headers: ["category": "announcement", "urgent": "false"]
            )
            
            try await chat.sendRichMessage(
                text: "Rich message with everything! ✨",
                metadata: ["emoji": "✨", "richText": true],
                headers: ["type": "rich", "version": "1.0"]
            )
            
            // Wait for messages to be processed
            print("⏳ Waiting for messages...")
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            
            // Cleanup
            try await chat.cleanup()
            print("✅ Quick Start example completed!")
            
        } catch {
            print("❌ Quick Start example failed: \(error)")
        }
    }
}

/*
USAGE:
1. Replace "YOUR_ABLY_API_KEY" with your actual Ably API key
2. Run the example:
   
   Task {
       await CompleteQuickStartExample().runExample()
   }
   
3. For SwiftUI integration, use @MainActor and StateObject:
   
   @StateObject private var chat = QuickStartChat()
   
   .task {
       await chat.initializeChat(apiKey: "YOUR_API_KEY", clientId: "user123")
       let room = try await chat.getRoom(named: "my-room")
       try await chat.subscribeToMessages()
   }

NEXT STEPS:
- Check out Authentication.swift for authentication patterns
- See MessageHandling.swift for advanced message operations  
- Look at PresenceAndTyping.swift for user presence features
- Explore SwiftUIComponents.swift for ready-to-use UI components
*/