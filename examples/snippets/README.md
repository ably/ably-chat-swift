# Ably Chat Swift SDK - Code Examples & Snippets

This directory contains comprehensive code examples and snippets for the Ably Chat Swift SDK. These examples are designed to help LLMs provide better working code to developers and serve as production-ready templates for common chat functionality.

## 📚 Available Examples

### 1. [QuickStart.swift](QuickStart.swift) - Getting Started
Complete minimal example showing basic chat setup and message sending.

**Key Features:**
- Basic chat client initialization
- Room creation and attachment
- Simple message sending and receiving
- Alternative authentication patterns
- SwiftUI integration examples

**Use Cases:**
- First-time SDK setup
- Proof of concept implementations
- Learning the basic SDK patterns

```swift
// Basic usage
let chat = QuickStartChat()
try await chat.initializeChat(apiKey: "YOUR_API_KEY", clientId: "user123")
let room = try await chat.getRoom(named: "general")
try await chat.sendMessage(text: "Hello, World!")
```

### 2. [Authentication.swift](Authentication.swift) - Authentication Patterns
Comprehensive authentication examples including token authentication, API key usage, and custom authentication.

**Key Features:**
- API key authentication for development
- JWT token authentication for production
- Token refresh mechanisms
- Custom authentication servers
- Authentication state management

**Use Cases:**
- Production authentication setup
- Token-based security implementation
- Custom backend integration

```swift
// Production token authentication
let chatClient = ChatAuthentication.authenticateWithTokenRefresh(
    initialToken: userToken,
    clientId: userId
) { tokenParams, callback in
    // Refresh token logic
}
```

### 3. [MessageHandling.swift](MessageHandling.swift) - Message Operations
Advanced message operations including sending, receiving, updating, deleting, and history management.

**Key Features:**
- Rich message sending with metadata and headers
- Real-time message subscription (callback and AsyncSequence)
- Message history and pagination
- Message updates and deletions
- Message filtering and searching
- Message threading support

**Use Cases:**
- Full-featured chat applications
- Message moderation systems
- Advanced message management

```swift
// Rich message handling
let messageHandler = MessageHandler(room: room)
try await messageHandler.sendRichMessage(
    text: "Hello with metadata!",
    metadata: ["type": "greeting", "priority": "high"],
    headers: ["category": "general"]
)
```

### 4. [PresenceAndTyping.swift](PresenceAndTyping.swift) - User Presence & Typing
User presence management and typing indicators implementation.

**Key Features:**
- User presence operations (enter, leave, update)
- Real-time presence event subscription
- Typing indicator management with auto-timeout
- Combined presence and typing UI manager
- Presence status definitions and user models

**Use Cases:**
- Online user tracking
- Typing indicators implementation
- User status management

```swift
// Smart typing management
let typingManager = SmartTypingManager(typingHandler: typingHandler)
try await typingManager.handleKeystroke() // Auto-stops after timeout

// Presence with rich user data
try await presenceHandler.enterPresenceWithUserInfo(
    name: "John Doe",
    status: "online",
    avatar: "https://example.com/avatar.jpg"
)
```

### 5. [Reactions.swift](Reactions.swift) - Reactions Implementation
Message reactions and room-level reactions with aggregation support.

**Key Features:**
- Message reactions (distinct, multiple, unique types)
- Room-level reactions for announcements
- Reaction aggregation and counting
- Real-time reaction subscriptions
- UI-ready reaction management
- Animation helpers for visual effects

**Use Cases:**
- Interactive message reactions
- Room-wide reaction systems
- Reaction analytics and aggregation

```swift
// Message reactions
let reactionHandler = MessageReactionHandler(room: room)
try await reactionHandler.addDistinctReaction(
    to: messageSerial,
    reactionName: "👍"
)

// Room reactions
try await roomReactionHandler.sendRoomReaction(reactionName: "🎉")
```

### 6. [RoomManagement.swift](RoomManagement.swift) - Room Operations
Comprehensive room management including creation, configuration, lifecycle management, and multi-room handling.

**Key Features:**
- Room creation with different configurations
- Room templates for common use cases
- Room lifecycle management (attach/detach/release)
- Room status monitoring and discontinuity handling
- Multi-room management
- Room feature analysis and optimization

**Use Cases:**
- Multi-room chat applications
- Room configuration optimization
- Room state management

```swift
// Room templates
let templateManager = RoomTemplateManager(chatClient: chatClient)
let supportRoom = try await templateManager.createRoomFromTemplate(
    name: "customer-support",
    template: .support
)

// Multi-room management
let multiRoomManager = MultiRoomManager(chatClient: chatClient)
try await multiRoomManager.joinRooms(["room1", "room2", "room3"])
```

### 7. [ErrorHandling.swift](ErrorHandling.swift) - Robust Error Handling
Comprehensive error handling patterns including connection errors, retry strategies, and offline queue management.

**Key Features:**
- Connection error analysis and recovery
- Retry strategies with exponential backoff
- Offline queue management
- Error recovery automation
- Network connectivity monitoring
- Graceful degradation patterns

**Use Cases:**
- Production-ready error handling
- Offline-first applications
- Robust connection management

```swift
// Resilient operations with retry and offline queue
let resilientOps = ResilientChatOperations(
    room: room,
    retryStrategy: RetryStrategy(maxRetries: 3),
    offlineQueue: offlineQueue
)

try await resilientOps.sendMessage(params: messageParams)
```

### 8. [SwiftUIComponents.swift](SwiftUIComponents.swift) - Ready-to-Use UI Components
Production-ready SwiftUI components for building chat interfaces.

**Key Features:**
- Complete `ChatView` with all features
- `MessageBubbleView` with reactions support
- `TypingIndicatorView` with animations
- `PresenceListView` for online users
- `ReactionPickerView` modal
- `MessageInputView` with typing detection
- Connection status indicators
- Responsive design and accessibility

**Use Cases:**
- Rapid UI development
- Consistent chat interface design
- SwiftUI best practices implementation

```swift
// Complete chat interface
struct ContentView: View {
    let room: Room
    
    var body: some View {
        ChatView(room: room)
    }
}

// Individual components
MessageBubbleView(
    message: message,
    isCurrentUser: message.clientID == currentUserId,
    onReactionTap: { message in /* handle reaction */ }
)
```

## 🚀 Quick Start Guide

### 1. Choose Your Starting Point

**For beginners:** Start with [`QuickStart.swift`](QuickStart.swift)
```swift
// Copy and paste this minimal example
let chat = QuickStartChat()
try await chat.initializeChat(apiKey: "YOUR_API_KEY", clientId: "user123")
let room = try await chat.getRoom(named: "general")
try await chat.subscribeToMessages()
try await chat.sendMessage(text: "Hello, Ably Chat!")
```

**For production apps:** Combine multiple examples
```swift
// 1. Setup authentication (Authentication.swift)
let chatClient = ChatAuthentication.authenticateWithToken(
    token: userToken,
    clientId: userId
)

// 2. Create resilient operations (ErrorHandling.swift)
let resilientOps = ResilientChatOperations(
    room: room,
    retryStrategy: RetryStrategy(),
    offlineQueue: OfflineQueueManager()
)

// 3. Use SwiftUI components (SwiftUIComponents.swift)
struct MyAppView: View {
    var body: some View {
        ChatView(room: room)
    }
}
```

### 2. Integration Patterns

#### For SwiftUI Apps
```swift
import SwiftUI
import AblyChat

struct ContentView: View {
    @StateObject private var authManager = ChatAuthenticationManager()
    @State private var room: Room?
    
    var body: some View {
        Group {
            if authManager.isAuthenticated, let room = room {
                ChatView(room: room)
            } else {
                LoginView(authManager: authManager)
            }
        }
        .task {
            if let chatClient = authManager.getChatClient() {
                room = try? await chatClient.rooms.get(roomName: "general", options: RoomOptions())
            }
        }
    }
}
```

#### For UIKit Apps
```swift
import UIKit
import AblyChat

class ChatViewController: UIViewController {
    private var room: Room?
    private let messageHandler: MessageHandler
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupChat()
    }
    
    private func setupChat() {
        Task {
            // Use examples from MessageHandling.swift
            let messageHandler = MessageHandler(room: room!)
            messageHandler.subscribeToMessages { [weak self] messageEvent in
                DispatchQueue.main.async {
                    self?.updateUI(with: messageEvent.message)
                }
            }
        }
    }
}
```

## 🔧 Configuration Examples

### Development Setup
```swift
// Using QuickStart.swift patterns
let devClient = ChatAuthentication.authenticateWithAPIKey(
    apiKey: "YOUR_DEV_API_KEY",
    clientId: "dev-user-\(UUID().uuidString)"
)
```

### Production Setup
```swift
// Using Authentication.swift + ErrorHandling.swift patterns
let prodClient = ChatAuthentication.authenticateWithTokenRefresh(
    initialToken: userToken,
    clientId: userId
) { tokenParams, callback in
    // Token refresh logic from Authentication.swift
}

let errorRecovery = ErrorRecoveryManager(chatClient: prodClient)
// Comprehensive error handling setup
```

### Feature-Specific Rooms
```swift
// Using RoomManagement.swift templates
let supportRoom = try await templateManager.createRoomFromTemplate(
    name: "support-\(ticketId)",
    template: .support  // Optimized for customer support
)

let gamingRoom = try await templateManager.createRoomFromTemplate(
    name: "game-lobby",
    template: .gaming   // Optimized for high-frequency messages
)
```

## 📱 Platform Support

All examples support:
- **iOS 15+** with full SwiftUI integration
- **macOS 12+** for desktop chat applications
- **async/await** for modern Swift concurrency
- **Combine** integration where appropriate
- **Accessibility** features built-in
- **Dark Mode** support

## 🛠 Customization Guide

### Styling
```swift
// Customize colors
ChatView(room: room)
    .accentColor(.purple)
    .background(Color(.systemGroupedBackground))

// Custom message bubbles
MessageBubbleView(/* parameters */)
    .foregroundColor(isCurrentUser ? .white : .primary)
    .background(isCurrentUser ? Color.purple : Color.gray)
```

### Behavior
```swift
// Custom retry strategy
let customRetry = RetryStrategy(
    maxRetries: 5,
    baseDelay: 2.0,
    maxDelay: 60.0,
    jitter: true
)

// Custom typing timeout
let typingOptions = TypingOptions(heartbeatThrottle: 5.0) // 5 seconds
```

### Features
```swift
// Enable/disable specific room features
let roomOptions = RoomOptions(
    messages: MessagesOptions(rawMessageReactions: true),
    presence: PresenceOptions(enableEvents: true),
    typing: TypingOptions(heartbeatThrottle: 3.0),
    occupancy: OccupancyOptions(enableEvents: true)
)
```

## ⚡ Performance Tips

1. **Use AsyncSequence**: Prefer AsyncSequence subscriptions for better memory management
2. **Optimize Room Options**: Disable unused features to reduce bandwidth
3. **Implement Offline Queue**: Use offline queue management for better UX
4. **Batch Operations**: Group multiple operations when possible
5. **Monitor Connection**: Implement connection status monitoring

## 🐛 Troubleshooting

### Common Issues

**Authentication Errors**
```swift
// Check ErrorHandling.swift for comprehensive error handling
let recoveryAction = ChatErrorHandler.handleChatError(error)
switch recoveryAction {
case .refreshAuth:
    // Implement token refresh
case .retryWithBackoff:
    // Implement retry logic
}
```

**Connection Issues**
```swift
// Use connection monitoring from ErrorHandling.swift
let errorRecovery = ErrorRecoveryManager(chatClient: chatClient)
errorRecovery.handleError(error, context: "connection")
```

**Room State Issues**
```swift
// Use room status monitoring from RoomManagement.swift
let statusMonitor = RoomStatusMonitor(room: room)
statusMonitor.startMonitoring()

// Wait for room to be ready
try await statusMonitor.waitForAttached()
```

### Debug Logging
```swift
// Enable detailed logging
let chatOptions = ChatClientOptions(
    logHandler: DefaultLogHandler(),
    logLevel: .debug
)
```

## 📚 Learning Path

1. **Start**: [`QuickStart.swift`](QuickStart.swift) - Understand basics
2. **Security**: [`Authentication.swift`](Authentication.swift) - Implement proper auth
3. **Features**: [`MessageHandling.swift`](MessageHandling.swift) - Add message features
4. **Users**: [`PresenceAndTyping.swift`](PresenceAndTyping.swift) - Track users
5. **Interaction**: [`Reactions.swift`](Reactions.swift) - Add reactions
6. **Scale**: [`RoomManagement.swift`](RoomManagement.swift) - Handle multiple rooms
7. **Production**: [`ErrorHandling.swift`](ErrorHandling.swift) - Make it robust
8. **UI**: [`SwiftUIComponents.swift`](SwiftUIComponents.swift) - Build interface

## 🔗 Additional Resources

- [Ably Chat Swift SDK Documentation](https://github.com/ably-labs/ably-chat-swift)
- [Ably Dashboard](https://ably.com/dashboard) - Manage API keys
- [Ably Documentation](https://ably.com/docs) - Platform documentation
- [Swift Concurrency Guide](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)

## 🤝 Contributing

These examples are designed to be comprehensive and production-ready. If you find issues or have improvements:

1. Each example file contains detailed usage instructions
2. All examples include error handling patterns
3. SwiftUI components include accessibility support
4. Mock implementations are provided for testing

## 📄 License

These examples are provided as part of the Ably Chat Swift SDK and follow the same license terms.

---

**Happy Chatting! 💬**

These examples provide everything you need to build production-ready chat applications with the Ably Chat Swift SDK. Each file is self-contained but designed to work together for comprehensive chat functionality.