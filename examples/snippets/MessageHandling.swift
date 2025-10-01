//
//  MessageHandling.swift
//  Ably Chat Swift SDK Examples
//
//  Message operations including sending, receiving, updating, deleting, and history
//  This example demonstrates comprehensive message handling with Ably Chat
//

import AblyChat
import Ably
import Foundation

// MARK: - Message Handling

/// Comprehensive examples for handling messages in Ably Chat
class MessageHandler {
    private let room: Room
    
    init(room: Room) {
        self.room = room
    }
    
    // MARK: - Sending Messages
    
    /// Send a simple text message
    /// - Parameter text: The message text to send
    /// - Returns: The sent message with its serial and metadata
    func sendSimpleMessage(text: String) async throws -> Message {
        let params = SendMessageParams(text: text)
        let message = try await room.messages.send(params: params)
        
        print("✅ Simple message sent:")
        print("   Serial: \(message.serial)")
        print("   Text: \(message.text)")
        print("   Client ID: \(message.clientID)")
        
        return message
    }
    
    /// Send message with metadata for rich features
    /// - Parameters:
    ///   - text: Message text
    ///   - metadata: Additional metadata for the message
    /// - Returns: The sent message
    func sendMessageWithMetadata(text: String, metadata: [String: Any]) async throws -> Message {
        let params = SendMessageParams(
            text: text,
            metadata: metadata
        )
        
        let message = try await room.messages.send(params: params)
        
        print("✅ Message with metadata sent:")
        print("   Serial: \(message.serial)")
        print("   Text: \(message.text)")
        print("   Metadata: \(message.metadata)")
        
        return message
    }
    
    /// Send message with headers for filtering and routing
    /// - Parameters:
    ///   - text: Message text
    ///   - headers: Headers for message filtering
    /// - Returns: The sent message
    func sendMessageWithHeaders(text: String, headers: [String: String]) async throws -> Message {
        let params = SendMessageParams(
            text: text,
            headers: headers
        )
        
        let message = try await room.messages.send(params: params)
        
        print("✅ Message with headers sent:")
        print("   Serial: \(message.serial)")
        print("   Headers: \(message.headers)")
        
        return message
    }
    
    /// Send rich message with both metadata and headers
    /// - Parameters:
    ///   - text: Message text
    ///   - metadata: Rich metadata
    ///   - headers: Message headers
    /// - Returns: The sent message
    func sendRichMessage(
        text: String,
        metadata: [String: Any],
        headers: [String: String]
    ) async throws -> Message {
        let params = SendMessageParams(
            text: text,
            metadata: metadata,
            headers: headers
        )
        
        let message = try await room.messages.send(params: params)
        
        print("✅ Rich message sent:")
        print("   Serial: \(message.serial)")
        print("   Text: \(message.text)")
        print("   Metadata: \(message.metadata)")
        print("   Headers: \(message.headers)")
        
        return message
    }
    
    // MARK: - Receiving Messages
    
    /// Subscribe to messages using callback approach
    /// - Parameter onMessage: Callback to handle incoming messages
    /// - Returns: Subscription for unsubscribing
    @discardableResult
    func subscribeToMessages(
        onMessage: @escaping (ChatMessageEvent) -> Void
    ) -> MessageSubscriptionResponseProtocol {
        let subscription = room.messages.subscribe { messageEvent in
            print("📨 Received message event:")
            print("   Type: \(messageEvent.type)")
            print("   Text: \(messageEvent.message.text)")
            print("   From: \(messageEvent.message.clientID)")
            print("   Serial: \(messageEvent.message.serial)")
            
            onMessage(messageEvent)
        }
        
        return subscription
    }
    
    /// Subscribe to messages using AsyncSequence (modern Swift approach)
    /// - Returns: AsyncSequence for iterating over messages
    func subscribeToMessagesAsync() -> MessageSubscriptionAsyncSequence {
        let subscription = room.messages.subscribe()
        
        // Start processing messages in background
        Task {
            for await messageEvent in subscription {
                await MainActor.run {
                    print("📨 Async message received:")
                    print("   Type: \(messageEvent.type)")
                    print("   Text: \(messageEvent.message.text)")
                    print("   From: \(messageEvent.message.clientID)")
                }
            }
        }
        
        return subscription
    }
    
    /// Subscribe to messages with custom buffering policy
    /// - Parameter bufferingPolicy: How to buffer incoming messages
    /// - Returns: AsyncSequence with custom buffering
    func subscribeToMessagesWithBuffering(
        bufferingPolicy: BufferingPolicy
    ) -> MessageSubscriptionAsyncSequence {
        return room.messages.subscribe(bufferingPolicy: bufferingPolicy)
    }
    
    // MARK: - Message History
    
    /// Get recent message history
    /// - Parameter limit: Maximum number of messages to retrieve
    /// - Returns: Paginated result containing messages
    func getRecentMessages(limit: Int = 50) async throws -> any PaginatedResult<Message> {
        let options = QueryOptions(
            limit: limit,
            orderBy: .newestFirst
        )
        
        let result = try await room.messages.history(options: options)
        
        print("📚 Retrieved \(result.items.count) recent messages")
        for message in result.items {
            print("   \(message.createdAt?.description ?? "Unknown"): \(message.text)")
        }
        
        return result
    }
    
    /// Get messages from a specific time range
    /// - Parameters:
    ///   - startDate: Start of time range
    ///   - endDate: End of time range
    ///   - limit: Maximum messages to retrieve
    /// - Returns: Messages in the time range
    func getMessagesInTimeRange(
        startDate: Date,
        endDate: Date,
        limit: Int = 100
    ) async throws -> any PaginatedResult<Message> {
        let options = QueryOptions(
            start: startDate,
            end: endDate,
            limit: limit,
            orderBy: .oldestFirst
        )
        
        let result = try await room.messages.history(options: options)
        
        print("📚 Retrieved \(result.items.count) messages from \(startDate) to \(endDate)")
        
        return result
    }
    
    /// Get messages with pagination
    /// - Parameter options: Query options for pagination
    /// - Returns: All messages using pagination
    func getAllMessagesWithPagination(options: QueryOptions? = nil) async throws -> [Message] {
        let initialOptions = options ?? QueryOptions(limit: 100, orderBy: .oldestFirst)
        var allMessages: [Message] = []
        
        var currentResult = try await room.messages.history(options: initialOptions)
        allMessages.append(contentsOf: currentResult.items)
        
        // Paginate through all results
        while currentResult.hasNext {
            currentResult = try await currentResult.next()
            allMessages.append(contentsOf: currentResult.items)
            
            print("📄 Fetched page with \(currentResult.items.count) messages (total: \(allMessages.count))")
        }
        
        print("📚 Retrieved total of \(allMessages.count) messages")
        return allMessages
    }
    
    // MARK: - Message Operations
    
    /// Update an existing message
    /// - Parameters:
    ///   - message: Original message to update
    ///   - newText: New text content
    ///   - description: Description of the update
    ///   - metadata: Update operation metadata
    /// - Returns: Updated message
    func updateMessage(
        _ message: Message,
        newText: String,
        description: String? = nil,
        metadata: OperationMetadata? = nil
    ) async throws -> Message {
        // Create updated message copy
        let updatedMessage = message.copy(text: newText)
        
        let result = try await room.messages.update(
            newMessage: updatedMessage,
            description: description,
            metadata: metadata
        )
        
        print("✏️ Message updated:")
        print("   Serial: \(result.serial)")
        print("   Original: \(message.text)")
        print("   Updated: \(result.text)")
        print("   Action: \(result.action)")
        
        return result
    }
    
    /// Update message with new metadata
    /// - Parameters:
    ///   - message: Original message
    ///   - newText: New text content
    ///   - newMetadata: New metadata
    ///   - description: Update description
    /// - Returns: Updated message
    func updateMessageWithMetadata(
        _ message: Message,
        newText: String,
        newMetadata: [String: Any],
        description: String? = nil
    ) async throws -> Message {
        let updatedMessage = message.copy(
            text: newText,
            metadata: newMetadata
        )
        
        let result = try await room.messages.update(
            newMessage: updatedMessage,
            description: description,
            metadata: ["updateType": "contentAndMetadata"]
        )
        
        print("✏️ Message updated with metadata:")
        print("   Serial: \(result.serial)")
        print("   New metadata: \(result.metadata)")
        
        return result
    }
    
    /// Delete a message
    /// - Parameters:
    ///   - message: Message to delete
    ///   - description: Reason for deletion
    ///   - metadata: Delete operation metadata
    /// - Returns: Deleted message
    func deleteMessage(
        _ message: Message,
        description: String? = nil,
        metadata: OperationMetadata? = nil
    ) async throws -> Message {
        let params = DeleteMessageParams(
            description: description,
            metadata: metadata
        )
        
        let result = try await room.messages.delete(message: message, params: params)
        
        print("🗑️ Message deleted:")
        print("   Serial: \(result.serial)")
        print("   Action: \(result.action)")
        print("   Description: \(description ?? "No reason provided")")
        
        return result
    }
    
    // MARK: - Message Filtering and Processing
    
    /// Filter messages by type using headers
    /// - Parameters:
    ///   - messageType: Type to filter by
    ///   - limit: Number of messages to check
    /// - Returns: Filtered messages
    func getMessagesByType(messageType: String, limit: Int = 100) async throws -> [Message] {
        let options = QueryOptions(limit: limit, orderBy: .newestFirst)
        let result = try await room.messages.history(options: options)
        
        let filteredMessages = result.items.filter { message in
            return message.headers["type"] as? String == messageType
        }
        
        print("🔍 Found \(filteredMessages.count) messages of type '\(messageType)'")
        
        return filteredMessages
    }
    
    /// Get messages from specific user
    /// - Parameters:
    ///   - clientId: User to filter by
    ///   - limit: Number of messages to check
    /// - Returns: Messages from the specified user
    func getMessagesFromUser(clientId: String, limit: Int = 100) async throws -> [Message] {
        let options = QueryOptions(limit: limit, orderBy: .newestFirst)
        let result = try await room.messages.history(options: options)
        
        let userMessages = result.items.filter { $0.clientID == clientId }
        
        print("👤 Found \(userMessages.count) messages from user '\(clientId)'")
        
        return userMessages
    }
    
    /// Search messages by text content
    /// - Parameters:
    ///   - searchTerm: Term to search for
    ///   - limit: Number of messages to check
    /// - Returns: Messages containing the search term
    func searchMessages(searchTerm: String, limit: Int = 100) async throws -> [Message] {
        let options = QueryOptions(limit: limit, orderBy: .newestFirst)
        let result = try await room.messages.history(options: options)
        
        let matchingMessages = result.items.filter { message in
            message.text.localizedCaseInsensitiveContains(searchTerm)
        }
        
        print("🔎 Found \(matchingMessages.count) messages containing '\(searchTerm)'")
        
        return matchingMessages
    }
}

// MARK: - Rich Message Examples

/// Examples of rich message handling with various content types
class RichMessageHandler {
    private let messageHandler: MessageHandler
    
    init(messageHandler: MessageHandler) {
        self.messageHandler = messageHandler
    }
    
    /// Send an announcement message
    func sendAnnouncement(title: String, content: String, priority: String = "normal") async throws -> Message {
        return try await messageHandler.sendRichMessage(
            text: "\(title)\n\n\(content)",
            metadata: [
                "type": "announcement",
                "title": title,
                "priority": priority,
                "timestamp": Date().timeIntervalSince1970
            ],
            headers: [
                "messageType": "announcement",
                "priority": priority
            ]
        )
    }
    
    /// Send a code snippet message
    func sendCodeSnippet(code: String, language: String, title: String? = nil) async throws -> Message {
        let text = title != nil ? "\(title!)\n\n```\(language)\n\(code)\n```" : "```\(language)\n\(code)\n```"
        
        return try await messageHandler.sendRichMessage(
            text: text,
            metadata: [
                "type": "code",
                "language": language,
                "code": code,
                "title": title as Any
            ],
            headers: [
                "messageType": "code",
                "language": language
            ]
        )
    }
    
    /// Send an image message with metadata
    func sendImageMessage(imageURL: String, caption: String? = nil, altText: String? = nil) async throws -> Message {
        let text = caption ?? "Image: \(imageURL)"
        
        return try await messageHandler.sendRichMessage(
            text: text,
            metadata: [
                "type": "image",
                "imageURL": imageURL,
                "caption": caption as Any,
                "altText": altText as Any,
                "mediaType": "image"
            ],
            headers: [
                "messageType": "media",
                "mediaType": "image"
            ]
        )
    }
    
    /// Send a poll message
    func sendPoll(question: String, options: [String], allowMultiple: Bool = false) async throws -> Message {
        let optionsText = options.enumerated().map { index, option in
            "\(index + 1). \(option)"
        }.joined(separator: "\n")
        
        let text = "\(question)\n\n\(optionsText)"
        
        return try await messageHandler.sendRichMessage(
            text: text,
            metadata: [
                "type": "poll",
                "question": question,
                "options": options,
                "allowMultiple": allowMultiple,
                "votes": [String: [String]]() // clientId -> selected options
            ],
            headers: [
                "messageType": "poll",
                "interactive": "true"
            ]
        )
    }
    
    /// Send a location message
    func sendLocation(latitude: Double, longitude: Double, name: String? = nil) async throws -> Message {
        let text = name ?? "Location: \(latitude), \(longitude)"
        
        return try await messageHandler.sendRichMessage(
            text: text,
            metadata: [
                "type": "location",
                "latitude": latitude,
                "longitude": longitude,
                "name": name as Any,
                "timestamp": Date().timeIntervalSince1970
            ],
            headers: [
                "messageType": "location",
                "hasCoordinates": "true"
            ]
        )
    }
}

// MARK: - Message Threading

/// Examples of message threading and replies
class MessageThreadHandler {
    private let messageHandler: MessageHandler
    
    init(messageHandler: MessageHandler) {
        self.messageHandler = messageHandler
    }
    
    /// Send a reply to a message
    func replyToMessage(
        _ parentMessage: Message,
        replyText: String
    ) async throws -> Message {
        return try await messageHandler.sendRichMessage(
            text: replyText,
            metadata: [
                "type": "reply",
                "parentMessageSerial": parentMessage.serial,
                "parentMessageText": parentMessage.text.prefix(100), // Preview
                "parentClientId": parentMessage.clientID
            ],
            headers: [
                "messageType": "reply",
                "parentSerial": parentMessage.serial
            ]
        )
    }
    
    /// Get all replies to a message
    func getReplies(to parentMessage: Message) async throws -> [Message] {
        let options = QueryOptions(limit: 100, orderBy: .oldestFirst)
        let result = try await messageHandler.room.messages.history(options: options)
        
        let replies = result.items.filter { message in
            if let parentSerial = message.metadata["parentMessageSerial"] as? String {
                return parentSerial == parentMessage.serial
            }
            return false
        }
        
        print("💬 Found \(replies.count) replies to message \(parentMessage.serial)")
        
        return replies
    }
    
    /// Create a message thread view
    func getMessageThread(rootMessage: Message) async throws -> MessageThread {
        let replies = try await getReplies(to: rootMessage)
        
        return MessageThread(
            rootMessage: rootMessage,
            replies: replies,
            totalCount: replies.count + 1
        )
    }
}

// MARK: - Models

/// Represents a message thread
struct MessageThread {
    let rootMessage: Message
    let replies: [Message]
    let totalCount: Int
    
    var allMessages: [Message] {
        return [rootMessage] + replies
    }
}

// MARK: - Message Event Handler

/// Comprehensive message event handler
@MainActor
class MessageEventHandler: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    
    private var subscription: MessageSubscriptionResponseProtocol?
    private let messageHandler: MessageHandler
    
    init(messageHandler: MessageHandler) {
        self.messageHandler = messageHandler
    }
    
    /// Start listening to message events
    func startListening() {
        subscription = messageHandler.subscribeToMessages { [weak self] messageEvent in
            Task { @MainActor in
                guard let self = self else { return }
                
                switch messageEvent.type {
                case .created:
                    self.handleNewMessage(messageEvent.message)
                case .updated:
                    self.handleUpdatedMessage(messageEvent.message)
                case .deleted:
                    self.handleDeletedMessage(messageEvent.message)
                }
            }
        }
    }
    
    /// Stop listening to message events
    func stopListening() {
        subscription?.unsubscribe()
        subscription = nil
    }
    
    /// Load message history
    func loadHistory(limit: Int = 50) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await messageHandler.getRecentMessages(limit: limit)
            messages = result.items.reversed() // Show oldest first in UI
        } catch {
            print("❌ Failed to load message history: \(error)")
        }
    }
    
    /// Send a new message
    func sendMessage(text: String, metadata: [String: Any]? = nil) async throws {
        if let metadata = metadata {
            try await messageHandler.sendMessageWithMetadata(text: text, metadata: metadata)
        } else {
            try await messageHandler.sendSimpleMessage(text: text)
        }
    }
    
    // MARK: - Private Event Handlers
    
    private func handleNewMessage(_ message: Message) {
        // Insert new message at the end (newest)
        messages.append(message)
        print("📨 New message added to UI: \(message.text)")
    }
    
    private func handleUpdatedMessage(_ message: Message) {
        // Find and replace the updated message
        if let index = messages.firstIndex(where: { $0.serial == message.serial }) {
            messages[index] = message
            print("✏️ Message updated in UI: \(message.text)")
        }
    }
    
    private func handleDeletedMessage(_ message: Message) {
        // Remove or mark as deleted
        if let index = messages.firstIndex(where: { $0.serial == message.serial }) {
            messages[index] = message // Keep the deleted message with delete action
            print("🗑️ Message deleted in UI: \(message.serial)")
        }
    }
}

// MARK: - Complete Message Handling Example

/// Complete example demonstrating all message handling features
class CompleteMessageHandlingExample {
    
    func runMessageHandlingExample(room: Room) async {
        print("📝 Running Message Handling Example")
        
        let messageHandler = MessageHandler(room: room)
        let richMessageHandler = RichMessageHandler(messageHandler: messageHandler)
        let threadHandler = MessageThreadHandler(messageHandler: messageHandler)
        
        do {
            // 1. Send various types of messages
            print("\n1. Sending different message types:")
            
            let simpleMessage = try await messageHandler.sendSimpleMessage(
                text: "Hello, this is a simple message!"
            )
            
            let richMessage = try await richMessageHandler.sendAnnouncement(
                title: "📢 Welcome!",
                content: "Welcome to our chat room. Please be respectful and follow the guidelines.",
                priority: "high"
            )
            
            let codeMessage = try await richMessageHandler.sendCodeSnippet(
                code: "print(\"Hello, World!\")",
                language: "swift",
                title: "Swift Hello World"
            )
            
            // 2. Subscribe to messages
            print("\n2. Setting up message subscription:")
            let subscription = messageHandler.subscribeToMessages { messageEvent in
                print("Received: \(messageEvent.message.text)")
            }
            
            // 3. Message operations
            print("\n3. Performing message operations:")
            
            let updatedMessage = try await messageHandler.updateMessage(
                simpleMessage,
                newText: "Hello, this is an UPDATED simple message!",
                description: "Fixed typo"
            )
            
            // 4. Message threading
            print("\n4. Message threading:")
            let replyMessage = try await threadHandler.replyToMessage(
                richMessage,
                replyText: "Thanks for the welcome! 👋"
            )
            
            // 5. Message history
            print("\n5. Loading message history:")
            let recentMessages = try await messageHandler.getRecentMessages(limit: 10)
            print("Loaded \(recentMessages.items.count) recent messages")
            
            // 6. Search and filter
            print("\n6. Searching messages:")
            let announcementMessages = try await messageHandler.getMessagesByType(
                messageType: "announcement",
                limit: 50
            )
            
            // Wait a bit to see subscription in action
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
            // 7. Cleanup
            subscription.unsubscribe()
            print("✅ Message handling example completed!")
            
        } catch {
            print("❌ Message handling example failed: \(error)")
        }
    }
}

/*
USAGE:

1. Basic message sending:
   let messageHandler = MessageHandler(room: room)
   try await messageHandler.sendSimpleMessage(text: "Hello!")

2. Rich messages:
   let richHandler = RichMessageHandler(messageHandler: messageHandler)
   try await richHandler.sendAnnouncement(
       title: "Important",
       content: "This is important!"
   )

3. Message subscription:
   messageHandler.subscribeToMessages { messageEvent in
       print("New message: \(messageEvent.message.text)")
   }

4. AsyncSequence subscription:
   let subscription = messageHandler.subscribeToMessagesAsync()
   for await messageEvent in subscription {
       print("Message: \(messageEvent.message.text)")
   }

5. SwiftUI integration:
   @StateObject private var eventHandler = MessageEventHandler(messageHandler: handler)
   
   .onAppear {
       await eventHandler.loadHistory()
       eventHandler.startListening()
   }
   
   .onDisappear {
       eventHandler.stopListening()
   }

6. Complete example:
   Task {
       await CompleteMessageHandlingExample().runMessageHandlingExample(room: room)
   }

FEATURES COVERED:
- Simple text messages
- Rich messages with metadata and headers
- Message subscription (callback and AsyncSequence)
- Message history and pagination
- Message updates and deletions
- Message filtering and searching
- Message threading and replies
- Event handling for UI integration
*/