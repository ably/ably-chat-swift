# Ably Chat Swift SDK - Examples & Quick Start Guide

This comprehensive **examples guide** provides working code samples and complete implementations for building **iOS chat applications** with the **Ably Chat Swift SDK**. From simple messaging to advanced features, these examples demonstrate production-ready **Swift chat development** patterns.

## Table of Contents

- [Complete Chat Application](#-complete-chat-application)
- [Quick Start Snippets](#-quick-start-snippets)
- [Feature-Specific Examples](#-feature-specific-examples)
- [UI Components](#-ui-components)
- [Advanced Patterns](#-advanced-patterns)

---

## 📱 Complete Chat Application

The **AblyChatExample** demonstrates a full-featured **SwiftUI chat app** showcasing all major SDK capabilities in a single, production-ready implementation.

### 🚀 Running the Example

1. **Open the Project**
   ```bash
   cd Example
   open AblyChatExample.xcodeproj
   ```

2. **Configure Environment**
   
   Edit [`ContentView.swift`](AblyChatExample/ContentView.swift:7):
   ```swift
   private enum Environment: Equatable {
       // For development: Use mock data
       static let current: Self = .mock
       
       // For live testing: Use your Ably API key
       // static let current: Self = .live(key: "YOUR_ABLY_API_KEY", clientId: "user123")
   }
   ```

3. **Build and Run**
   - Select your target device/simulator
   - Press `Cmd+R` to build and run
   - The app starts with mock data - perfect for testing UI and interactions

### 🎯 Example Features Demonstrated

| Feature | Implementation | File Reference |
|---------|---------------|----------------|
| **Real-time Messaging** | Send, edit, delete messages | [`ContentView.swift:255`](AblyChatExample/ContentView.swift:255) |
| **Message Reactions** | Add emoji reactions to messages | [`MessageReactionsPicker.swift`](AblyChatExample/MessageViews/MessageReactionsPicker.swift) |
| **Typing Indicators** | Show who's currently typing | [`ContentView.swift:338`](AblyChatExample/ContentView.swift:338) |
| **User Presence** | Track online/offline status | [`ContentView.swift:323`](AblyChatExample/ContentView.swift:323) |
| **Room Reactions** | Animated floating reactions | [`ContentView.swift:294`](AblyChatExample/ContentView.swift:294) |
| **Occupancy Metrics** | Real-time connection counts | [`ContentView.swift:348`](AblyChatExample/ContentView.swift:348) |
| **Connection Management** | Handle reconnection and status | [`ContentView.swift:361`](AblyChatExample/ContentView.swift:361) |

### 🔧 Example Architecture

```swift
// Main chat interface with comprehensive features
struct ContentView: View {
    @State private var chatClient = Environment.current.createChatClient()
    @State private var listItems = [ListItem]()
    @State private var newMessage = ""
    
    // Unified list supporting messages and presence events
    enum ListItem: Identifiable {
        case message(MessageListItem)
        case presence(PresenceListItem)
    }
    
    var body: some View {
        VStack {
            // Room info and status
            Text("In \(roomName) as \(currentClientID)")
            
            // Dynamic message list with animations
            List(listItems, id: \.id) { item in
                switch item {
                case let .message(messageItem):
                    MessageView(/* ... */)
                case let .presence(presenceItem):
                    PresenceMessageView(/* ... */)
                }
            }
            .flip() // Custom flip animation for chat UX
            
            // Message input with typing detection
            HStack {
                TextField("Type a message...", text: $newMessage)
                    .onChange(of: newMessage) { startTyping() }
                Button(sendTitle, action: sendButtonAction)
            }
        }
        .task {
            await setupChatRoom()
        }
    }
}
```

---

## ⚡ Quick Start Snippets

### Basic Chat Setup

```swift
import AblyChat
import Ably
import SwiftUI

// 1. Initialize Chat Client
@State private var chatClient: ChatClient = {
    let options = ARTClientOptions(key: "YOUR_ABLY_API_KEY")
    options.clientId = "user123"
    let realtime = ARTRealtime(options: options)
    return DefaultChatClient(realtime: realtime, clientOptions: ChatClientOptions())
}()

// 2. Create and Join Room
private func setupRoom() async throws {
    let room = try await chatClient.rooms.get(
        "my-chat-room",
        options: RoomOptions(
            presence: PresenceOptions(enableEvents: true),
            typing: TypingOptions(),
            reactions: RoomReactionOptions()
        )
    )
    try await room.attach()
}
```

### Send Your First Message

```swift
// Simple message sending
func sendMessage(_ text: String) async throws {
    let room = try await chatClient.rooms.get("my-chat-room")
    
    let message = try await room.messages.send(
        params: SendMessageParams(
            text: text,
            metadata: ["timestamp": Date().timeIntervalSince1970]
        )
    )
    
    print("Message sent: \(message.id)")
}

// Usage
Task {
    try await sendMessage("Hello, world! 👋")
}
```

### Real-time Message Subscription

```swift
// Subscribe to incoming messages
func subscribeToMessages() async {
    let room = try await chatClient.rooms.get("my-chat-room")
    
    for await messageEvent in room.messages.subscribe() {
        switch messageEvent.type {
        case .created:
            print("📨 New message: \(messageEvent.message.text)")
            updateUI(with: messageEvent.message)
            
        case .updated:
            print("✏️ Message edited: \(messageEvent.message.text)")
            refreshMessage(messageEvent.message)
            
        case .deleted:
            print("🗑️ Message deleted: \(messageEvent.message.id)")
            removeMessage(messageEvent.message.id)
        }
    }
}
```

### User Presence Tracking

```swift
// Track user presence
func setupPresence() async throws {
    let room = try await chatClient.rooms.get("my-chat-room")
    
    // Enter presence
    try await room.presence.enter(data: [
        "status": "online",
        "avatar": "https://example.com/avatar.jpg"
    ])
    
    // Subscribe to presence changes
    for await presenceEvent in room.presence.subscribe(events: [.enter, .leave]) {
        switch presenceEvent.type {
        case .enter:
            print("👋 \(presenceEvent.member.clientID) joined")
        case .leave:
            print("👋 \(presenceEvent.member.clientID) left")
        default:
            break
        }
    }
}
```

---

## 🎯 Feature-Specific Examples

### Message Reactions

```swift
// Add reaction to message
func addReaction(to messageSerial: String, reaction: String) async throws {
    let room = try await chatClient.rooms.get("my-chat-room")
    
    try await room.messages.reactions.send(
        to: messageSerial,
        params: SendMessageReactionParams(
            name: reaction,
            type: .unique // or .multiple for counting
        )
    )
}

// Subscribe to reaction updates
func subscribeToReactions() async {
    let room = try await chatClient.rooms.get("my-chat-room")
    
    for await reactionEvent in room.messages.reactions.subscribe() {
        print("Reaction '\(reactionEvent.type)' on message \(reactionEvent.messageId)")
        updateMessageReactions(reactionEvent)
    }
}

// Usage
Task {
    try await addReaction(to: "message-serial-123", reaction: "👍")
}
```

### Typing Indicators

```swift
// Handle typing indicators
func handleTyping(isTyping: Bool) async throws {
    let room = try await chatClient.rooms.get("my-chat-room")
    
    if isTyping {
        try await room.typing.keystroke()
    } else {
        try await room.typing.stop()
    }
}

// Subscribe to typing events
func subscribeToTyping() async {
    let room = try await chatClient.rooms.get("my-chat-room")
    
    for await typingEvent in room.typing.subscribe() {
        let typingUsers = Array(typingEvent.currentlyTyping)
        updateTypingIndicator(users: typingUsers)
    }
}

// SwiftUI TextField integration
TextField("Type message...", text: $messageText)
    .onChange(of: messageText) { newValue in
        Task {
            try? await handleTyping(isTyping: !newValue.isEmpty)
        }
    }
```

### Room-Level Reactions (Floating Animations)

```swift
// Send floating reaction
func sendFloatingReaction(_ emoji: String) async throws {
    let room = try await chatClient.rooms.get("my-chat-room")
    
    try await room.reactions.send(
        params: SendReactionParams(
            name: emoji,
            metadata: [
                "animation": "float",
                "duration": 3.0
            ]
        )
    )
}

// Animated reaction display (from example)
func showReaction(_ emoji: String) {
    let newReaction = Reaction(
        id: UUID(),
        emoji: emoji,
        xPosition: CGFloat.random(in: 50...300),
        yPosition: screenHeight - 100,
        scale: 1.0,
        opacity: 1.0
    )
    
    reactions.append(newReaction)
    
    withAnimation(.easeOut(duration: 3.0)) {
        moveReactionUp(reaction: newReaction)
    }
    
    // Cleanup after animation
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
        reactions.removeAll { $0.id == newReaction.id }
    }
}
```

### Message History & Pagination

```swift
// Load message history with pagination
func loadMessageHistory() async throws {
    let room = try await chatClient.rooms.get("my-chat-room")
    
    // Load recent messages
    let history = try await room.messages.history(
        options: QueryOptions(
            limit: 50,
            orderBy: .newestFirst
        )
    )
    
    messages = history.items
    
    // Load more if available
    if let next = history.next {
        let olderMessages = try await next()
        messages.append(contentsOf: olderMessages.items)
    }
}

// Infinite scroll implementation
ScrollView {
    LazyVStack {
        ForEach(messages, id: \.id) { message in
            MessageRow(message: message)
                .onAppear {
                    if message == messages.last {
                        Task { try await loadMoreMessages() }
                    }
                }
        }
    }
}
```

---

## 🎨 UI Components

### Custom Message Bubble

```swift
struct MessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading) {
                Text(message.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        isCurrentUser ? Color.blue : Color(.systemGray5)
                    )
                    .foregroundColor(
                        isCurrentUser ? .white : .primary
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !isCurrentUser { Spacer() }
        }
    }
}
```

### Typing Indicator Component

```swift
struct TypingIndicatorView: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .offset(y: animationOffset)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: animationOffset
                    )
            }
        }
        .onAppear {
            animationOffset = -8
        }
    }
}
```

### Reaction Picker (From Example)

From [`MessageReactionsPicker.swift`](AblyChatExample/MessageViews/MessageReactionsPicker.swift):

```swift
struct MessageReactionsPicker: View {
    let onReactionSelected: (String) -> Void
    private let emojies = ["😀", "😂", "❤️", "👍", "👎", "😮", "🔥", "🎉"]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
                ForEach(emojies, id: \.self) { emoji in
                    Text(emoji)
                        .font(.system(size: 32))
                        .padding()
                        .onTapGesture {
                            onReactionSelected(emoji)
                        }
                }
            }
        }
        .presentationDetents([.fraction(0.5)])
    }
}
```

### Connection Status Indicator

```swift
struct ConnectionStatusView: View {
    let connectionStatus: ConnectionStatus
    
    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        switch connectionStatus {
        case .connected: return .green
        case .connecting: return .orange
        default: return .red
        }
    }
    
    private var statusText: String {
        switch connectionStatus {
        case .connected: return "Online"
        case .connecting: return "Connecting..."
        default: return "Offline"
        }
    }
}
```

---

## 🏗️ Advanced Patterns

### Multi-Room Chat Manager

```swift
@MainActor
class ChatManager: ObservableObject {
    private let chatClient: ChatClient
    @Published var activeRooms: [String: Room] = [:]
    @Published var messages: [String: [Message]] = [:]
    
    init(chatClient: ChatClient) {
        self.chatClient = chatClient
    }
    
    func joinRoom(_ roomId: String) async throws {
        let room = try await chatClient.rooms.get(roomId, options: RoomOptions())
        try await room.attach()
        
        activeRooms[roomId] = room
        messages[roomId] = []
        
        // Subscribe to messages for this room
        Task {
            for await messageEvent in room.messages.subscribe() {
                switch messageEvent.type {
                case .created:
                    messages[roomId, default: []].append(messageEvent.message)
                default:
                    break
                }
            }
        }
    }
    
    func leaveRoom(_ roomId: String) async {
        guard let room = activeRooms[roomId] else { return }
        
        try? await room.detach()
        activeRooms.removeValue(forKey: roomId)
        messages.removeValue(forKey: roomId)
    }
}
```

### Message Queue with Offline Support

```swift
class MessageQueue: ObservableObject {
    private var pendingMessages: [PendingMessage] = []
    private let chatClient: ChatClient
    
    struct PendingMessage {
        let roomId: String
        let text: String
        let timestamp: Date
        let metadata: MessageMetadata?
    }
    
    func queueMessage(_ message: PendingMessage) {
        pendingMessages.append(message)
        attemptToSend()
    }
    
    private func attemptToSend() {
        guard chatClient.connection.status == .connected else { return }
        
        Task {
            for message in pendingMessages {
                do {
                    let room = try await chatClient.rooms.get(message.roomId)
                    try await room.messages.send(
                        params: SendMessageParams(
                            text: message.text,
                            metadata: message.metadata
                        )
                    )
                } catch {
                    print("Failed to send queued message: \(error)")
                    break // Stop processing on error
                }
            }
            pendingMessages.removeAll()
        }
    }
}
```

### Custom Room Options Factory

```swift
struct RoomOptionsFactory {
    static func basicChat() -> RoomOptions {
        RoomOptions(
            presence: PresenceOptions(enableEvents: true),
            typing: TypingOptions(),
            messages: MessagesOptions()
        )
    }
    
    static func livestreamChat() -> RoomOptions {
        RoomOptions(
            presence: PresenceOptions(enableEvents: true),
            reactions: RoomReactionOptions(),
            occupancy: OccupancyOptions(enableEvents: true),
            messages: MessagesOptions(
                defaultMessageReactionType: .multiple
            )
        )
    }
    
    static func supportChat() -> RoomOptions {
        RoomOptions(
            presence: PresenceOptions(enableEvents: true),
            typing: TypingOptions(heartbeatThrottle: 2.0),
            messages: MessagesOptions(),
            metadata: ["type": "support_session"]
        )
    }
}
```

---

## 📚 Additional Resources

### Running Examples with Live Data

1. **Get Ably API Key**
   - Sign up at [ably.com](https://ably.com)
   - Create a new app in your dashboard
   - Copy your API key

2. **Configure Live Environment**
   ```swift
   // In ContentView.swift
   static let current: Self = .live(
       key: "YOUR_ABLY_API_KEY", 
       clientId: "unique-user-id"
   )
   ```

3. **Test Real-time Features**
   - Run multiple simulator instances
   - Open the same room in each
   - Test messaging, reactions, and presence

### Example Project Structure

```
Example/AblyChatExample/
├── AblyChatExampleApp.swift      # Main app entry point
├── ContentView.swift             # Primary chat interface
├── MessageViews/                 # Message-related UI components
│   ├── MessageView.swift         # Individual message display
│   ├── MessageReactionsPicker.swift # Emoji reaction picker
│   ├── MessageReactionSummaryView.swift # Reaction display
│   └── PresenceMessageView.swift # Presence event display
├── Misc/
│   └── Utils.swift              # Helper functions and extensions
└── Mocks/                       # Mock implementations for testing
    ├── MockClients.swift
    ├── MockRealtime.swift
    └── MockSubscriptionStorage.swift
```

### Key Learning Points

1. **SwiftUI Integration**: The example shows modern SwiftUI patterns with async/await
2. **Real-time Animations**: Floating reactions demonstrate engaging user interactions  
3. **Mock vs Live**: Easy switching between development and production environments
4. **Comprehensive Features**: Single example covers all major SDK capabilities
5. **Production Patterns**: Error handling, connection management, and offline support

### Next Steps

- **Study the Complete Example**: Run and explore [`AblyChatExample`](AblyChatExample/)
- **Implement Gradually**: Start with basic messaging, add features incrementally
- **Customize UI**: Adapt the provided components to your app's design system
- **Test Thoroughly**: Use mock mode for development, live mode for integration testing
- **Production Deployment**: Review [security guidelines](../docs/FEATURES.md#security--compliance) before going live

---

*Ready to build? Start with the [complete example](AblyChatExample/) or jump to specific [feature implementations](../docs/FEATURES.md) based on your needs.*