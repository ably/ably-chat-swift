# Ably Chat Swift SDK - Complete Use Case Implementation Guide

This comprehensive guide demonstrates how to implement common **chat use cases** using the **Ably Chat Swift SDK**. Each use case includes architecture patterns, implementation examples, and best practices for building production-ready **iOS chat applications**.

## Table of Contents

- [In-App Messaging](#-in-app-messaging)
- [Customer Support Chat](#-customer-support-chat)  
- [Live Collaboration](#-live-collaboration)
- [Gaming Chat](#-gaming-chat)
- [Social Messaging](#-social-messaging)
- [Team Communication](#-team-communication)

---

## 💬 In-App Messaging

**Keywords**: in-app messaging, user-to-user chat, direct messaging, social app chat, marketplace communication

Build **peer-to-peer messaging** for social apps, marketplaces, dating apps, and community platforms where users communicate privately.

### Key Requirements

- ✅ **Private 1:1 conversations** between users
- ✅ **User discovery** and contact management
- ✅ **Message threading** and conversation history
- ✅ **Read receipts** and delivery status
- ✅ **Rich media support** (images, files, links)
- ✅ **Push notifications** for new messages
- ✅ **Blocked users** and privacy controls

### Architecture Pattern

```swift
import AblyChat
import SwiftUI

// Core messaging manager
@MainActor
class InAppMessagingManager: ObservableObject {
    private let chatClient: ChatClient
    private let currentUserId: String
    
    @Published var conversations: [Conversation] = []
    @Published var activeConversation: Conversation?
    
    private var conversationRooms: [String: Room] = [:]
    
    init(chatClient: ChatClient, currentUserId: String) {
        self.chatClient = chatClient
        self.currentUserId = currentUserId
    }
    
    // Create or get existing conversation
    func getConversation(with userId: String) async throws -> Conversation {
        let conversationId = createConversationId(user1: currentUserId, user2: userId)
        
        // Configure room for private messaging
        let roomOptions = RoomOptions(
            presence: PresenceOptions(enableEvents: true),
            typing: TypingOptions(),
            messages: MessagesOptions(
                defaultMessageReactionType: .unique
            )
        )
        
        let room = try await chatClient.rooms.get(conversationId, options: roomOptions)
        try await room.attach()
        
        conversationRooms[conversationId] = room
        
        let conversation = Conversation(
            id: conversationId,
            participantId: userId,
            room: room
        )
        
        // Add to active conversations if not exists
        if !conversations.contains(where: { $0.id == conversationId }) {
            conversations.append(conversation)
        }
        
        return conversation
    }
    
    private func createConversationId(user1: String, user2: String) -> String {
        // Ensure consistent conversation ID regardless of order
        let sortedUsers = [user1, user2].sorted()
        return "dm_\(sortedUsers[0])_\(sortedUsers[1])"
    }
}

// Conversation model
struct Conversation: Identifiable, Equatable {
    let id: String
    let participantId: String
    let room: Room
    
    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        lhs.id == rhs.id
    }
}
```

### Message Implementation

```swift
// SwiftUI conversation view
struct ConversationView: View {
    let conversation: Conversation
    @State private var messages: [Message] = []
    @State private var messageText = ""
    @State private var isTyping = false
    @State private var otherUserTyping = false
    
    var body: some View {
        VStack {
            // Messages list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages, id: \.id) { message in
                        MessageBubbleView(
                            message: message,
                            isFromCurrentUser: message.clientId == getCurrentUserId()
                        )
                    }
                }
                .padding(.horizontal)
            }
            
            // Typing indicator
            if otherUserTyping {
                TypingIndicatorView()
                    .padding(.horizontal)
            }
            
            // Message input
            MessageInputView(
                text: $messageText,
                isTyping: $isTyping,
                onSend: sendMessage,
                onTypingChanged: handleTypingChanged
            )
        }
        .navigationTitle("Chat")
        .task {
            await setupMessageSubscription()
            await loadMessageHistory()
            await setupTypingSubscription()
        }
        .onDisappear {
            Task {
                try? await conversation.room.typing.stop()
            }
        }
    }
    
    private func setupMessageSubscription() async {
        for await messageEvent in conversation.room.messages.subscribe() {
            switch messageEvent.type {
            case .created:
                messages.append(messageEvent.message)
                markAsRead(messageEvent.message)
                
            case .updated:
                updateMessage(messageEvent.message)
                
            case .deleted:
                removeMessage(messageEvent.message.id)
            }
        }
    }
    
    private func loadMessageHistory() async {
        do {
            let history = try await conversation.room.messages.history(
                options: QueryOptions(limit: 50, orderBy: .newestFirst)
            )
            messages = history.items.reversed()
        } catch {
            print("Failed to load message history: \(error)")
        }
    }
    
    private func setupTypingSubscription() async {
        for await typingEvent in conversation.room.typing.subscribe() {
            let typingUsers = typingEvent.currentlyTyping.subtracting([getCurrentUserId()])
            otherUserTyping = !typingUsers.isEmpty
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        Task {
            do {
                let message = try await conversation.room.messages.send(
                    params: SendMessageParams(
                        text: messageText,
                        metadata: [
                            "messageType": "text",
                            "timestamp": Date().timeIntervalSince1970
                        ]
                    )
                )
                
                messageText = ""
                try? await conversation.room.typing.stop()
                
            } catch {
                print("Failed to send message: \(error)")
                // Show error to user
            }
        }
    }
    
    private func handleTypingChanged(_ typing: Bool) {
        Task {
            if typing {
                try? await conversation.room.typing.keystroke()
            } else {
                try? await conversation.room.typing.stop()
            }
        }
    }
}

// Message bubble component
struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        isFromCurrentUser ? Color.blue : Color(.systemGray5)
                    )
                    .foregroundColor(
                        isFromCurrentUser ? .white : .primary
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 18)
                    )
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !isFromCurrentUser {
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
```

### User Discovery & Privacy

```swift
// User management for in-app messaging
class UserManager: ObservableObject {
    @Published var blockedUsers: Set<String> = []
    @Published var contacts: [User] = []
    
    func blockUser(_ userId: String) {
        blockedUsers.insert(userId)
        // Remove from contacts and close conversations
        contacts.removeAll { $0.id == userId }
    }
    
    func unblockUser(_ userId: String) {
        blockedUsers.remove(userId)
    }
    
    func canMessageUser(_ userId: String) -> Bool {
        !blockedUsers.contains(userId)
    }
}

// Enhanced messaging manager with privacy controls
extension InAppMessagingManager {
    func sendMessage(to userId: String, text: String) async throws {
        guard userManager.canMessageUser(userId) else {
            throw MessagingError.userBlocked
        }
        
        let conversation = try await getConversation(with: userId)
        
        try await conversation.room.messages.send(
            params: SendMessageParams(
                text: text,
                headers: [
                    "x-recipient": userId,
                    "x-message-type": "direct"
                ]
            )
        )
    }
    
    func reportMessage(_ message: Message) async {
        // Report inappropriate content
        let reportData = [
            "messageId": message.id,
            "reportedBy": currentUserId,
            "timestamp": Date().timeIntervalSince1970,
            "reason": "inappropriate_content"
        ]
        
        // Send to moderation system
        await moderationService.reportMessage(reportData)
    }
}
```

### Best Practices

- **Privacy First**: Implement user blocking and reporting from day one
- **Efficient Loading**: Use pagination for message history  
- **Typing Optimization**: Throttle typing events to prevent spam
- **Push Notifications**: Integrate for better engagement
- **Media Handling**: Support image and file sharing with proper moderation

---

## 🎧 Customer Support Chat

**Keywords**: customer support chat, help desk integration, agent chat, support tickets, live chat widget

Build **customer support experiences** with agent assignment, conversation routing, and integration with existing support systems.

### Key Requirements

- ✅ **Agent-customer pairing** with skill-based routing
- ✅ **Queue management** for waiting customers  
- ✅ **Agent presence** and availability status
- ✅ **Conversation handoffs** between agents
- ✅ **Rich context** with customer history and metadata
- ✅ **Internal agent tools** (notes, tags, escalation)
- ✅ **SLA tracking** and performance metrics

### Architecture Pattern

```swift
import AblyChat
import SwiftUI

// Support system manager
@MainActor
class SupportChatManager: ObservableObject {
    private let chatClient: ChatClient
    
    @Published var customerQueue: [SupportRequest] = []
    @Published var activeAgents: [SupportAgent] = []
    @Published var activeSessions: [SupportSession] = []
    
    private let agentPresenceRoom: Room
    private let queueRoom: Room
    
    init(chatClient: ChatClient) async throws {
        self.chatClient = chatClient
        
        // Global rooms for coordination
        self.agentPresenceRoom = try await chatClient.rooms.get(
            "support_agents",
            options: RoomOptions(
                presence: PresenceOptions(enableEvents: true)
            )
        )
        
        self.queueRoom = try await chatClient.rooms.get(
            "support_queue", 
            options: RoomOptions()
        )
        
        try await agentPresenceRoom.attach()
        try await queueRoom.attach()
        
        await setupAgentPresenceTracking()
        await setupQueueManagement()
    }
    
    // Customer initiates support request
    func createSupportRequest(
        customerId: String,
        issue: String,
        priority: SupportPriority = .normal,
        department: String = "general"
    ) async throws -> SupportSession {
        
        let sessionId = "support_\(customerId)_\(Date().timeIntervalSince1970)"
        
        // Create dedicated room for this support session
        let sessionRoom = try await chatClient.rooms.get(
            sessionId,
            options: RoomOptions(
                presence: PresenceOptions(enableEvents: true),
                typing: TypingOptions(),
                metadata: [
                    "type": "support_session",
                    "customerId": customerId,
                    "priority": priority.rawValue,
                    "department": department
                ]
            )
        )
        
        try await sessionRoom.attach()
        
        // Add customer context message
        try await sessionRoom.messages.send(
            params: SendMessageParams(
                text: issue,
                metadata: [
                    "messageType": "initial_request",
                    "customerId": customerId,
                    "priority": priority.rawValue,
                    "department": department,
                    "timestamp": Date().timeIntervalSince1970
                ]
            )
        )
        
        let session = SupportSession(
            id: sessionId,
            customerId: customerId,
            room: sessionRoom,
            status: .waiting,
            priority: priority,
            department: department,
            createdAt: Date()
        )
        
        activeSessions.append(session)
        
        // Notify queue management
        try await notifyQueue(session: session)
        
        return session
    }
    
    // Agent accepts support request
    func acceptSupportRequest(
        sessionId: String,
        agentId: String
    ) async throws -> SupportSession {
        
        guard let sessionIndex = activeSessions.firstIndex(where: { $0.id == sessionId }) else {
            throw SupportError.sessionNotFound
        }
        
        var session = activeSessions[sessionIndex]
        session.agentId = agentId
        session.status = .active
        session.assignedAt = Date()
        
        activeSessions[sessionIndex] = session
        
        // Agent enters the session room
        try await session.room.presence.enter(data: [
            "agentId": agentId,
            "role": "agent",
            "joinedAt": Date().timeIntervalSince1970
        ])
        
        // Send assignment notification
        try await session.room.messages.send(
            params: SendMessageParams(
                text: "Hi! I'm here to help you with your request.",
                metadata: [
                    "messageType": "agent_assignment",
                    "agentId": agentId,
                    "systemMessage": true
                ]
            )
        )
        
        return session
    }
}

// Support models
struct SupportSession: Identifiable {
    let id: String
    let customerId: String
    let room: Room
    var agentId: String?
    var status: SupportStatus
    let priority: SupportPriority
    let department: String
    let createdAt: Date
    var assignedAt: Date?
    var resolvedAt: Date?
}

enum SupportStatus {
    case waiting
    case active
    case resolved
    case escalated
}

enum SupportPriority: String, CaseIterable {
    case low = "low"
    case normal = "normal"  
    case high = "high"
    case urgent = "urgent"
}

struct SupportAgent: Identifiable {
    let id: String
    let name: String
    let departments: [String]
    var status: AgentStatus
    var currentSessions: Int
    let maxSessions: Int
}

enum AgentStatus {
    case available
    case busy
    case away
    case offline
}
```

### Agent Dashboard Implementation

```swift
// SwiftUI agent interface
struct AgentDashboardView: View {
    @StateObject private var supportManager: SupportChatManager
    @State private var selectedSession: SupportSession?
    
    let agentId: String
    
    var body: some View {
        NavigationView {
            // Session list sidebar
            List {
                Section("Waiting Requests") {
                    ForEach(waitingRequests) { session in
                        SupportRequestRow(
                            session: session,
                            onAccept: { 
                                Task {
                                    try await supportManager.acceptSupportRequest(
                                        sessionId: session.id,
                                        agentId: agentId
                                    )
                                }
                            }
                        )
                    }
                }
                
                Section("My Active Sessions") {
                    ForEach(myActiveSessions) { session in
                        ActiveSessionRow(
                            session: session,
                            isSelected: selectedSession?.id == session.id
                        )
                        .onTapGesture {
                            selectedSession = session
                        }
                    }
                }
            }
            .navigationTitle("Support Queue")
            
            // Chat interface
            if let session = selectedSession {
                SupportChatView(session: session, agentId: agentId)
            } else {
                Text("Select a session to start chatting")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var waitingRequests: [SupportSession] {
        supportManager.activeSessions.filter { $0.status == .waiting }
    }
    
    private var myActiveSessions: [SupportSession] {
        supportManager.activeSessions.filter { 
            $0.agentId == agentId && $0.status == .active 
        }
    }
}

// Support chat interface with agent tools
struct SupportChatView: View {
    let session: SupportSession
    let agentId: String
    
    @State private var messages: [Message] = []
    @State private var messageText = ""
    @State private var customerTyping = false
    @State private var internalNotes: [InternalNote] = []
    @State private var showingNoteSheet = false
    
    var body: some View {
        VStack {
            // Customer info header
            CustomerInfoHeader(session: session)
            
            // Chat messages
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages, id: \.id) { message in
                        SupportMessageView(
                            message: message,
                            isFromAgent: message.clientId == agentId
                        )
                    }
                }
                .padding()
            }
            
            // Agent tools toolbar
            AgentToolsBar(
                session: session,
                onAddNote: { showingNoteSheet = true },
                onEscalate: escalateSession,
                onResolve: resolveSession
            )
            
            // Message input
            MessageInputView(
                text: $messageText,
                placeholder: "Type your response...",
                onSend: sendMessage
            )
        }
        .navigationTitle("Support Chat")
        .sheet(isPresented: $showingNoteSheet) {
            InternalNoteSheet(session: session) { note in
                internalNotes.append(note)
            }
        }
        .task {
            await setupChatSubscription()
            await loadChatHistory()
        }
    }
    
    private func sendMessage() {
        Task {
            try await session.room.messages.send(
                params: SendMessageParams(
                    text: messageText,
                    metadata: [
                        "messageType": "agent_response",
                        "agentId": agentId,
                        "timestamp": Date().timeIntervalSince1970
                    ]
                )
            )
            messageText = ""
        }
    }
    
    private func escalateSession() {
        Task {
            try await session.room.messages.send(
                params: SendMessageParams(
                    text: "This conversation has been escalated to a senior agent.",
                    metadata: [
                        "messageType": "escalation",
                        "escalatedBy": agentId,
                        "systemMessage": true
                    ]
                )
            )
            
            // Update session status
            // Implementation depends on your escalation workflow
        }
    }
    
    private func resolveSession() {
        Task {
            try await session.room.messages.send(
                params: SendMessageParams(
                    text: "This support session has been resolved. Is there anything else I can help you with?",
                    metadata: [
                        "messageType": "resolution",
                        "resolvedBy": agentId,
                        "systemMessage": true
                    ]
                )
            )
            
            // Update session status and collect feedback
        }
    }
}
```

### Queue Management & Routing

```swift
// Intelligent request routing
class SupportRouter {
    private let supportManager: SupportChatManager
    
    func routeRequest(_ session: SupportSession) async -> String? {
        let availableAgents = await getAvailableAgents(
            department: session.department,
            priority: session.priority
        )
        
        // Route based on workload and specialization
        let bestAgent = availableAgents
            .filter { $0.currentSessions < $0.maxSessions }
            .sorted { agent1, agent2 in
                // Prioritize agents with fewer current sessions
                if agent1.currentSessions != agent2.currentSessions {
                    return agent1.currentSessions < agent2.currentSessions
                }
                
                // Then by department specialization
                let agent1Specialization = agent1.departments.contains(session.department)
                let agent2Specialization = agent2.departments.contains(session.department) 
                
                if agent1Specialization != agent2Specialization {
                    return agent1Specialization
                }
                
                return false
            }
            .first
        
        return bestAgent?.id
    }
    
    private func getAvailableAgents(
        department: String,
        priority: SupportPriority
    ) async -> [SupportAgent] {
        
        return supportManager.activeAgents.filter { agent in
            agent.status == .available &&
            (agent.departments.contains(department) || department == "general") &&
            canHandlePriority(agent: agent, priority: priority)
        }
    }
    
    private func canHandlePriority(agent: SupportAgent, priority: SupportPriority) -> Bool {
        // Implement agent capability matching
        switch priority {
        case .urgent:
            return agent.departments.contains("escalation") || agent.maxSessions >= 3
        default:
            return true
        }
    }
}
```

### Best Practices

- **SLA Tracking**: Monitor response and resolution times
- **Agent Load Balancing**: Distribute requests based on capacity
- **Context Preservation**: Maintain customer history across sessions
- **Quality Assurance**: Implement chat monitoring and feedback
- **Escalation Paths**: Clear workflows for complex issues

---

## 🤝 Live Collaboration 

**Keywords**: live collaboration, document collaboration, real-time editing, collaborative workspace, team coordination

Build **collaborative workspaces** where team members work together on documents, projects, or shared tasks in real-time.

### Key Requirements

- ✅ **Multi-user editing** with conflict resolution
- ✅ **Real-time cursors** and selection indicators  
- ✅ **Collaborative commenting** on specific elements
- ✅ **Version history** and change tracking
- ✅ **User awareness** showing active collaborators
- ✅ **Permission systems** (view/edit/admin roles)
- ✅ **Activity notifications** for important changes

### Architecture Pattern

```swift
import AblyChat
import SwiftUI

// Collaborative workspace manager
@MainActor 
class CollaborationManager: ObservableObject {
    private let chatClient: ChatClient
    private let currentUserId: String
    
    @Published var activeWorkspaces: [CollaborativeWorkspace] = []
    @Published var collaborators: [Collaborator] = []
    @Published var documentState: DocumentState?
    
    private var workspaceRooms: [String: Room] = [:]
    
    init(chatClient: ChatClient, currentUserId: String) {
        self.chatClient = chatClient
        self.currentUserId = currentUserId
    }
    
    // Join collaborative workspace
    func joinWorkspace(_ workspaceId: String, role: CollaboratorRole = .editor) async throws -> CollaborativeWorkspace {
        
        let roomOptions = RoomOptions(
            presence: PresenceOptions(enableEvents: true),
            typing: TypingOptions(heartbeatThrottle: 1.0), // Faster for cursors
            reactions: RoomReactionOptions(), // For quick feedback
            occupancy: OccupancyOptions(enableEvents: true)
        )
        
        let room = try await chatClient.rooms.get("workspace_\(workspaceId)", options: roomOptions)
        try await room.attach()
        
        workspaceRooms[workspaceId] = room
        
        // Enter presence with collaborator info
        try await room.presence.enter(data: [
            "userId": currentUserId,
            "role": role.rawValue,
            "cursor": nil, // Will be updated with cursor position
            "selection": nil, // Current selection area
            "activeElement": nil, // Currently focused element
            "joinedAt": Date().timeIntervalSince1970
        ])
        
        let workspace = CollaborativeWorkspace(
            id: workspaceId,
            room: room,
            currentUserRole: role
        )
        
        if !activeWorkspaces.contains(where: { $0.id == workspaceId }) {
            activeWorkspaces.append(workspace)
        }
        
        await setupCollaborationSubscriptions(workspace)
        
        return workspace
    }
    
    // Send document operation (for operational transformation)
    func sendDocumentOperation(
        workspaceId: String,
        operation: DocumentOperation
    ) async throws {
        
        guard let room = workspaceRooms[workspaceId] else {
            throw CollaborationError.workspaceNotFound
        }
        
        try await room.messages.send(
            params: SendMessageParams(
                text: "", // Operation data in metadata
                metadata: [
                    "operationType": "document_operation",
                    "operation": operation.toJSON(),
                    "userId": currentUserId,
                    "timestamp": Date().timeIntervalSince1970,
                    "version": documentState?.version ?? 0
                ],
                headers: [
                    "x-operation-type": operation.type.rawValue
                ]
            )
        )
    }
    
    // Update cursor position for real-time awareness
    func updateCursorPosition(workspaceId: String, position: CursorPosition) async {
        guard let room = workspaceRooms[workspaceId] else { return }
        
        try? await room.presence.update(data: [
            "userId": currentUserId,
            "cursor": position.toJSON(),
            "lastActivity": Date().timeIntervalSince1970
        ])
    }
    
    // Add collaborative comment
    func addComment(
        workspaceId: String,
        elementId: String,
        text: String,
        position: CommentPosition
    ) async throws {
        
        guard let room = workspaceRooms[workspaceId] else {
            throw CollaborationError.workspaceNotFound
        }
        
        try await room.messages.send(
            params: SendMessageParams(
                text: text,
                metadata: [
                    "messageType": "comment",
                    "elementId": elementId,
                    "position": position.toJSON(),
                    "userId": currentUserId,
                    "timestamp": Date().timeIntervalSince1970
                ]
            )
        )
    }
    
    private func setupCollaborationSubscriptions(_ workspace: CollaborativeWorkspace) async {
        // Document operations
        Task {
            for await messageEvent in workspace.room.messages.subscribe() {
                await handleCollaborativeMessage(messageEvent, workspace: workspace)
            }
        }
        
        // Presence updates (cursors, selections)
        Task {
            for await presenceEvent in workspace.room.presence.subscribe(events: [.enter, .update, .leave]) {
                await handlePresenceUpdate(presenceEvent, workspace: workspace)
            }
        }
        
        // Typing indicators for active editing
        Task {
            for await typingEvent in workspace.room.typing.subscribe() {
                await handleTypingUpdate(typingEvent, workspace: workspace)
            }
        }
    }
}

// Collaboration models
struct CollaborativeWorkspace: Identifiable {
    let id: String
    let room: Room
    let currentUserRole: CollaboratorRole
}

struct Collaborator: Identifiable {
    let id: String
    let name: String
    let role: CollaboratorRole
    var cursorPosition: CursorPosition?
    var isActive: Bool
    var lastActivity: Date
}

enum CollaboratorRole: String, CaseIterable {
    case viewer = "viewer"
    case editor = "editor" 
    case admin = "admin"
}

struct DocumentOperation {
    let id: String
    let type: OperationType
    let position: Int
    let content: String?
    let length: Int?
    
    enum OperationType: String {
        case insert
        case delete
        case format
        case move
    }
}

struct CursorPosition {
    let x: Double
    let y: Double
    let elementId: String?
    let textPosition: Int?
}
```

### Real-Time Document Editor

```swift
// SwiftUI collaborative document editor
struct CollaborativeEditorView: View {
    let workspace: CollaborativeWorkspace
    @StateObject private var collaboration: CollaborationManager
    
    @State private var documentText = ""
    @State private var cursorPosition: CursorPosition?
    @State private var collaborators: [Collaborator] = []
    @State private var comments: [CollaborativeComment] = []
    @State private var selectedRange: NSRange?
    
    var body: some View {
        VStack(spacing: 0) {
            // Collaboration toolbar
            CollaborationToolbar(
                collaborators: collaborators,
                workspace: workspace
            )
            
            // Document editor with cursors
            ZStack {
                // Main text editor
                TextEditor(text: $documentText)
                    .font(.system(size: 16, family: .monospaced))
                    .onChange(of: documentText) { newValue in
                        handleTextChange(newValue)
                    }
                    .onReceive(NotificationCenter.default.publisher(
                        for: UITextView.textDidChangeSelectionNotification
                    )) { notification in
                        handleSelectionChange(notification)
                    }
                
                // Collaborative cursors overlay
                CollaborativeCursorsOverlay(
                    collaborators: collaborators,
                    documentText: documentText
                )
                
                // Comments overlay
                CommentsOverlay(
                    comments: comments,
                    onAddComment: addComment
                )
            }
            
            // Comment sidebar (if active)
            if !comments.isEmpty {
                CommentSidebar(
                    comments: comments,
                    onReply: replyToComment,
                    onResolve: resolveComment
                )
                .frame(width: 300)
            }
        }
        .navigationTitle("Collaborative Document")
        .task {
            await loadDocumentState()
            await setupCollaborationListeners()
        }
    }
    
    private func handleTextChange(_ newText: String) {
        // Calculate operation from text diff
        let operation = calculateOperation(
            from: documentText,
            to: newText
        )
        
        Task {
            try await collaboration.sendDocumentOperation(
                workspaceId: workspace.id,
                operation: operation
            )
        }
        
        updateCursorPosition()
    }
    
    private func handleSelectionChange(_ notification: Notification) {
        guard let textView = notification.object as? UITextView else { return }
        
        let position = CursorPosition(
            x: textView.caretRect(for: textView.selectedTextRange?.start ?? UITextPosition()).origin.x,
            y: textView.caretRect(for: textView.selectedTextRange?.start ?? UITextPosition()).origin.y,
            elementId: "main_document",
            textPosition: textView.selectedRange.location
        )
        
        cursorPosition = position
        
        Task {
            await collaboration.updateCursorPosition(
                workspaceId: workspace.id,
                position: position
            )
        }
    }
    
    private func addComment(at position: CommentPosition, text: String) {
        Task {
            try await collaboration.addComment(
                workspaceId: workspace.id,
                elementId: "main_document",
                text: text,
                position: position
            )
        }
    }
}

// Real-time cursor visualization
struct CollaborativeCursorsOverlay: View {
    let collaborators: [Collaborator]
    let documentText: String
    
    var body: some View {
        ForEach(collaborators.filter { $0.cursorPosition != nil }) { collaborator in
            if let cursor = collaborator.cursorPosition {
                CollaborativeCursor(
                    collaborator: collaborator,
                    position: cursor
                )
                .position(x: cursor.x, y: cursor.y)
            }
        }
    }
}

struct CollaborativeCursor: View {
    let collaborator: Collaborator
    let position: CursorPosition
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // User label
            Text(collaborator.name)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(collaboratorColor.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(4)
            
            // Cursor line
            Rectangle()
                .fill(collaboratorColor)
                .frame(width: 2, height: 20)
        }
    }
    
    private var collaboratorColor: Color {
        // Generate consistent color per user
        Color(hue: Double(collaborator.id.hashValue % 360) / 360.0,
              saturation: 0.7,
              brightness: 0.8)
    }
}
```

### Operational Transformation

```swift
// Conflict resolution for concurrent edits
class OperationalTransform {
    static func transform(
        operation1: DocumentOperation,
        operation2: DocumentOperation
    ) -> (DocumentOperation, DocumentOperation) {
        
        // Handle concurrent operations based on type
        switch (operation1.type, operation2.type) {
        case (.insert, .insert):
            return transformInsertInsert(operation1, operation2)
            
        case (.delete, .delete):
            return transformDeleteDelete(operation1, operation2)
            
        case (.insert, .delete):
            return transformInsertDelete(operation1, operation2)
            
        case (.delete, .insert):
            let (op2, op1) = transformInsertDelete(operation2, operation1)
            return (op1, op2)
            
        default:
            // Format and move operations
            return (operation1, operation2)
        }
    }
    
    private static func transformInsertInsert(
        _ op1: DocumentOperation,
        _ op2: DocumentOperation
    ) -> (DocumentOperation, DocumentOperation) {
        
        if op1.position <= op2.position {
            // op1 comes first, adjust op2 position
            let newOp2 = DocumentOperation(
                id: op2.id,
                type: op2.type,
                position: op2.position + (op1.content?.count ?? 0),
                content: op2.content,
                length: op2.length
            )
            return (op1, newOp2)
        } else {
            // op2 comes first, adjust op1 position
            let newOp1 = DocumentOperation(
                id: op1.id,
                type: op1.type,
                position: op1.position + (op2.content?.count ?? 0),
                content: op1.content,
                length: op1.length
            )
            return (newOp1, op2)
        }
    }
    
    // Additional transformation methods...
}
```

### Best Practices

- **Conflict Resolution**: Implement operational transformation for concurrent edits
- **Performance**: Throttle cursor updates and batch operations  
- **Permissions**: Enforce role-based editing permissions
- **Version Control**: Track document versions and change history
- **Offline Support**: Queue operations when disconnected

---

## 🎮 Gaming Chat

**Keywords**: gaming chat, multiplayer chat, in-game communication, voice integration, team coordination

Build **in-game communication systems** for multiplayer games, including team coordination, spectator chat, and cross-platform messaging.

### Key Requirements

- ✅ **Low-latency messaging** for real-time coordination
- ✅ **Multiple chat channels** (team, global, private)
- ✅ **Quick reactions** for fast-paced gameplay
- ✅ **Spectator interactions** with limited permissions
- ✅ **Moderation tools** for toxic behavior
- ✅ **Cross-platform compatibility** (iOS, Android, Web)
- ✅ **Integration with game events** and statistics

### Architecture Pattern

```swift
import AblyChat
import SwiftUI
import GameKit

// Gaming chat manager
@MainActor
class GameChatManager: ObservableObject {
    private let chatClient: ChatClient
    private let gameId: String
    private let playerId: String
    
    @Published var teamChat: Room?
    @Published var globalChat: Room? 
    @Published var spectatorChat: Room?
    @Published var privateChats: [String: Room] = [:]
    
    @Published var activeChannel: ChatChannel = .team
    @Published var quickReactions: [String] = ["👍", "👎", "😂", "😱", "🔥", "💯"]
    
    private var gameEventSubscription: AnyCancellable?
    
    enum ChatChannel: String, CaseIterable {
        case team = "team"
        case global = "global"
        case spectator = "spectator"
        case private = "private"
        
        var displayName: String {
            switch self {
            case .team: return "Team"
            case .global: return "All"
            case .spectator: return "Spectators"
            case .private: return "DM"
            }
        }
    }
    
    init(chatClient: ChatClient, gameId: String, playerId: String) {
        self.chatClient = chatClient
        self.gameId = gameId
        self.playerId = playerId
    }
    
    // Setup game chat rooms
    func setupGameChat(playerRole: PlayerRole, teamId: String?) async throws {
        
        // Team chat (only for players in the same team)
        if let teamId = teamId, playerRole == .player {
            teamChat = try await createTeamChat(teamId: teamId)
        }
        
        // Global game chat (all participants)
        globalChat = try await createGlobalChat()
        
        // Spectator chat (spectators only)
        if playerRole == .spectator {
            spectatorChat = try await createSpectatorChat()
        }
        
        // Setup game event integration
        setupGameEventIntegration()
    }
    
    private func createTeamChat(teamId: String) async throws -> Room {
        let room = try await chatClient.rooms.get(
            "game_\(gameId)_team_\(teamId)",
            options: RoomOptions(
                presence: PresenceOptions(enableEvents: true),
                typing: TypingOptions(heartbeatThrottle: 0.5), // Fast for gaming
                reactions: RoomReactionOptions(),
                metadata: [
                    "chatType": "team",
                    "gameId": gameId,
                    "teamId": teamId
                ]
            )
        )
        
        try await room.attach()
        
        // Enter presence with player info
        try await room.presence.enter(data: [
            "playerId": playerId,
            "role": "player",
            "teamId": teamId,
            "gameStatus": "active"
        ])
        
        return room
    }
    
    private func createGlobalChat() async throws -> Room {
        let room = try await chatClient.rooms.get(
            "game_\(gameId)_global",
            options: RoomOptions(
                presence: PresenceOptions(enableEvents: true),
                reactions: RoomReactionOptions(),
                occupancy: OccupancyOptions(enableEvents: true),
                metadata: [
                    "chatType": "global",
                    "gameId": gameId
                ]
            )
        )
        
        try await room.attach()
        return room
    }
    
    // Send quick message with game context
    func sendQuickMessage(
        channel: ChatChannel,
        type: QuickMessageType
    ) async throws {
        
        let room = getRoomForChannel(channel)
        let messageText = getQuickMessageText(type)
        
        try await room?.messages.send(
            params: SendMessageParams(
                text: messageText,
                metadata: [
                    "messageType": "quick_message",
                    "quickType": type.rawValue,
                    "playerId": playerId,
                    "gameContext": getCurrentGameContext()
                ]
            )
        )
    }
    
    // Send game event message
    func sendGameEventMessage(
        event: GameEvent,
        channel: ChatChannel = .global
    ) async throws {
        
        let room = getRoomForChannel(channel)
        
        try await room?.messages.send(
            params: SendMessageParams(
                text: event.description,
                metadata: [
                    "messageType": "game_event",
                    "eventType": event.type,
                    "playerId": playerId,
                    "eventData": event.data,
                    "timestamp": Date().timeIntervalSince1970
                ]
            )
        )
    }
    
    // Quick reaction for fast-paced games
    func sendQuickReaction(
        reaction: String,
        channel: ChatChannel = .team
    ) async throws {
        
        let room = getRoomForChannel(channel)
        
        try await room?.reactions.send(
            params: SendReactionParams(
                name: reaction,
                metadata: [
                    "playerId": playerId,
                    "reactionContext": getCurrentGameContext()
                ]
            )
        )
    }
}

// Gaming-specific models
enum PlayerRole {
    case player
    case spectator
    case moderator
}

enum QuickMessageType: String, CaseIterable {
    case needHelp = "need_help"
    case onMyWay = "on_my_way"
    case wellDone = "well_done"
    case fallBack = "fall_back"
    case pushForward = "push_forward"
    
    var displayText: String {
        switch self {
        case .needHelp: return "Need help!"
        case .onMyWay: return "On my way"
        case .wellDone: return "Well done!"
        case .fallBack: return "Fall back"
        case .pushForward: return "Push forward"
        }
    }
}

struct GameEvent {
    let type: String
    let description: String
    let data: [String: Any]
}
```

### Gaming Chat UI Implementation

```swift
// SwiftUI gaming chat interface
struct GameChatView: View {
    @StateObject private var chatManager: GameChatManager
    @State private var messageText = ""
    @State private var messages: [Message] = []
    @State private var showingQuickActions = false
    
    let gameId: String
    let playerId: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat channel selector
            ChatChannelPicker(
                selectedChannel: $chatManager.activeChannel,
                availableChannels: availableChannels
            )
            
            // Messages area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(messages, id: \.id) { message in
                            GameChatMessageView(
                                message: message,
                                isCurrentPlayer: message.clientId == playerId
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: messages.count) { _ in
                    // Auto-scroll to bottom
                    if let lastMessage = messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            
            // Gaming chat input
            GameChatInputView(
                text: $messageText,
                onSend: sendMessage,
                onQuickAction: { showingQuickActions.toggle() },
                onQuickReaction: sendQuickReaction
            )
            
            // Quick actions panel
            if showingQuickActions {
                QuickActionsPanel(
                    onQuickMessage: sendQuickMessage,
                    onDismiss: { showingQuickActions = false }
                )
                .transition(.move(edge: .bottom))
            }
        }
        .background(Color(.systemBackground))
        .task {
            await setupGameChat()
            await subscribeToMessages()
        }
    }
    
    private var availableChannels: [GameChatManager.ChatChannel] {
        var channels: [GameChatManager.ChatChannel] = [.global]
        
        if chatManager.teamChat != nil {
            channels.insert(.team, at: 0)
        }
        
        if chatManager.spectatorChat != nil {
            channels.append(.spectator)
        }
        
        return channels
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        Task {
            do {
                let room = chatManager.getRoomForChannel(chatManager.activeChannel)
                try await room?.messages.send(
                    params: SendMessageParams(
                        text: messageText,
                        metadata: [
                            "messageType": "player_message",
                            "playerId": playerId,
                            "channel": chatManager.activeChannel.rawValue
                        ]
                    )
                )
                messageText = ""
            } catch {
                print("Failed to send message: \(error)")
            }
        }
    }
    
    private func sendQuickMessage(_ type: QuickMessageType) {
        Task {
            try await chatManager.sendQuickMessage(
                channel: chatManager.activeChannel,
                type: type
            )
        }
        showingQuickActions = false
    }
    
    private func sendQuickReaction(_ reaction: String) {
        Task {
            try await chatManager.sendQuickReaction(
                reaction: reaction,
                channel: chatManager.activeChannel
            )
        }
    }
}

// Gaming-optimized message view
struct GameChatMessageView: View {
    let message: Message
    let isCurrentPlayer: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Player indicator
            Circle()
                .fill(playerColor)
                .frame(width: 8, height: 8)
                .offset(y: 4)
            
            VStack(alignment: .leading, spacing: 2) {
                // Player name and timestamp
                HStack {
                    Text(getPlayerName(message.clientId))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(playerColor)
                    
                    Spacer()
                    
                    Text(formatGameTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Message content with game-specific formatting
                if isGameEventMessage {
                    GameEventMessageView(message: message)
                } else if isQuickMessage {
                    QuickMessageView(message: message)
                } else {
                    Text(message.text)
                        .font(.callout)
                }
            }
            
            Spacer(minLength: 40)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            isCurrentPlayer ? Color.blue.opacity(0.1) : Color.clear
        )
        .cornerRadius(8)
    }
    
    private var playerColor: Color {
        // Generate team-based colors
        if let teamId = message.metadata?["teamId"] as? String {
            return teamId == "team_1" ? .blue : .red
        }
        return .green
    }
    
    private var isGameEventMessage: Bool {
        message.metadata?["messageType"] as? String == "game_event"
    }
    
    private var isQuickMessage: Bool {
        message.metadata?["messageType"] as? String == "quick_message"
    }
}

// Quick actions for fast-paced gaming
struct QuickActionsPanel: View {
    let onQuickMessage: (QuickMessageType) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Quick Messages")
                .font(.headline)
                .padding(.top)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(QuickMessageType.allCases, id: \.self) { type in
                    Button(action: {
                        onQuickMessage(type)
                    }) {
                        Text(type.displayText)
                            .font(.callout)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
            
            Button("Cancel") {
                onDismiss()
            }
            .padding(.bottom)
        }
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}
```

### Game Event Integration

```swift
// Integration with game events
extension GameChatManager {
    func setupGameEventIntegration() {
        // Listen to GameKit or custom game events
        gameEventSubscription = NotificationCenter.default
            .publisher(for: .gameEventOccurred)
            .sink { [weak self] notification in
                Task { @MainActor in
                    await self?.handleGameEvent(notification)
                }
            }
    }
    
    private func handleGameEvent(_ notification: Notification) async {
        guard let eventInfo = notification.userInfo else { return }
        
        // Convert game events to chat messages
        if let eventType = eventInfo["type"] as? String {
            let gameEvent = GameEvent(
                type: eventType,
                description: generateEventDescription(eventType, eventInfo),
                data: eventInfo
            )
            
            // Send to appropriate channel
            let channel: ChatChannel = shouldBroadcastGlobally(eventType) ? .global : .team
            
            try? await sendGameEventMessage(event: gameEvent, channel: channel)
        }
    }
    
    private func generateEventDescription(_ eventType: String, _ eventInfo: [AnyHashable: Any]) -> String {
        switch eventType {
        case "player_eliminated":
            return "\(playerId) was eliminated!"
        case "objective_captured":
            return "\(playerId) captured the objective!"
        case "level_completed":
            return "Level completed! 🎉"
        case "power_up_collected":
            if let powerUp = eventInfo["powerUpType"] as? String {
                return "\(playerId) collected \(powerUp)!"
            }
            return "\(playerId) collected a power-up!"
        default:
            return "Game event: \(eventType)"
        }
    }
}

// Notification extensions for game events
extension Notification.Name {
    static let gameEventOccurred = Notification.Name("gameEventOccurred")
}
```

### Best Practices

- **Low Latency**: Use minimal typing throttle for real-time coordination
- **Quick Actions**: Provide pre-defined messages for common situations
- **Channel Management**: Separate team/global/spectator communications
- **Moderation**: Implement automated filtering for toxic behavior
- **Performance**: Optimize for high-frequency message scenarios

---

## 📱 Social Messaging

**Keywords**: social messaging, community chat, social platform, user engagement, social features

Build **social platform messaging** with community features, user interactions, and engagement mechanics for social apps and community platforms.

### Key Requirements

- ✅ **Community channels** with topic-based discussions
- ✅ **User profiles** and social interactions  
- ✅ **Message sharing** and viral mechanics
- ✅ **Social reactions** and engagement features
- ✅ **Content moderation** and community guidelines
- ✅ **Trending topics** and discoverability
- ✅ **Social notifications** and activity feeds

### Architecture Pattern

```swift
import AblyChat
import SwiftUI

// Social messaging manager
@MainActor
class SocialMessagingManager: ObservableObject {
    private let chatClient: ChatClient
    private let currentUserId: String
    
    @Published var communities: [Community] = []
    @Published var trendingTopics: [TrendingTopic] = []
    @Published var socialFeed: [SocialMessage] = []
    @Published var notifications: [SocialNotification] = []
    
    private var communityRooms: [String: Room] = [:]
    private var followedUsers: Set<String> = []
    
    init(chatClient: ChatClient, currentUserId: String) {
        self.chatClient = chatClient
        self.currentUserId = currentUserId
    }
    
    // Join community channel
    func joinCommunity(_ communityId: String) async throws -> Community {
        
        let roomOptions = RoomOptions(
            presence: PresenceOptions(enableEvents: true),
            typing: TypingOptions(),
            reactions: RoomReactionOptions(),
            occupancy: OccupancyOptions(enableEvents: true),
            messages: MessagesOptions(
                defaultMessageReactionType: .multiple // Allow multiple reactions
            )
        )
        
        let room = try await chatClient.rooms.get("community_\(communityId)", options: roomOptions)
        try await room.attach()
        
        communityRooms[communityId] = room
        
        // Enter with social profile data
        try await room.presence.enter(data: [
            "userId": currentUserId,
            "username": await getUserProfile(currentUserId).username,
            "avatar": await getUserProfile(currentUserId).avatar,
            "reputation": await getUserProfile(currentUserId).reputation,
            "joinedAt": Date().timeIntervalSince1970
        ])
        
        let community = Community(
            id: communityId,
            room: room,
            memberCount: 0
        )
        
        await setupCommunitySubscriptions(community)
        
        if !communities.contains(where: { $0.id == communityId }) {
            communities.append(community)
        }
        
        return community
    }
    
    // Post social message with engagement features
    func postMessage(
        communityId: String,
        text: String,
        mediaAttachments: [MediaAttachment] = [],
        tags: [String] = []
    ) async throws -> SocialMessage {
        
        guard let room = communityRooms[communityId] else {
            throw SocialError.communityNotFound
        }
        
        let message = try await room.messages.send(
            params: SendMessageParams(
                text: text,
                metadata: [
                    "messageType": "social_post",
                    "userId": currentUserId,
                    "mediaAttachments": mediaAttachments.map { $0.toJSON() },
                    "tags": tags,
                    "timestamp": Date().timeIntervalSince1970,
                    "engagementMetrics": [
                        "likes": 0,
                        "shares": 0,
                        "comments": 0
                    ]
                ]
            )
        )
        
        let socialMessage = SocialMessage(
            id: message.id,
            text: message.text,
            author: await getUserProfile(currentUserId),
            timestamp: message.timestamp,
            mediaAttachments: mediaAttachments,
            tags: tags,
            engagementMetrics: EngagementMetrics()
        )
        
        // Add to social feed
        socialFeed.insert(socialMessage, at: 0)
        
        return socialMessage
    }
    
    // Social engagement actions
    func likeMessage(messageId: String, communityId: String) async throws {
        guard let room = communityRooms[communityId] else { return }
        
        // Send like reaction
        try await room.messages.reactions.send(
            to: messageId,
            params: SendMessageReactionParams(
                name: "❤️",
                type: .unique
            )
        )
        
        // Update engagement metrics
        await updateEngagementMetrics(messageId: messageId, action: .like)
    }
    
    func shareMessage(messageId: String, to targetCommunityId: String) async throws {
        guard let originalMessage = socialFeed.first(where: { $0.id == messageId }),
              let targetRoom = communityRooms[targetCommunityId] else { return }
        
        // Create share message
        try await targetRoom.messages.send(
            params: SendMessageParams(
                text: "Shared from @\(originalMessage.author.username): \(originalMessage.text)",
                metadata: [
                    "messageType": "shared_post",
                    "originalMessageId": messageId,
                    "originalAuthor": originalMessage.author.id,
                    "sharedBy": currentUserId,
                    "timestamp": Date().timeIntervalSince1970
                ]
            )
        )
        
        await updateEngagementMetrics(messageId: messageId, action: .share)
    }
    
    // Trending topic discovery
    func updateTrendingTopics() async {
        let topicAnalyzer = TrendingTopicAnalyzer()
        
        // Analyze recent messages across communities
        let recentMessages = socialFeed.filter {
            $0.timestamp.timeIntervalSinceNow > -3600 // Last hour
        }
        
        trendingTopics = await topicAnalyzer.analyzeTrends(from: recentMessages)
    }
}

// Social models
struct Community: Identifiable {
    let id: String
    let room: Room
    var memberCount: Int
    var description: String?
    var rules: [String] = []
    var moderators: [String] = []
}

struct SocialMessage: Identifiable {
    let id: String
    let text: String
    let author: UserProfile
    let timestamp: Date
    let mediaAttachments: [MediaAttachment]
    let tags: [String]
    var engagementMetrics: EngagementMetrics
    var comments: [Comment] = []
}

struct UserProfile {
    let id: String
    let username: String
    let avatar: String?
    let reputation: Int
    let followersCount: Int
    let followingCount: Int
}

struct EngagementMetrics {
    var likes: Int = 0
    var shares: Int = 0  
    var comments: Int = 0
    var reactions: [String: Int] = [:]
}

enum SocialEngagementAction {
    case like
    case share
    case comment
    case reaction(String)
}
```

### Social Feed Implementation

```swift
// SwiftUI social messaging interface
struct SocialFeedView: View {
    @StateObject private var socialManager: SocialMessagingManager
    @State private var selectedCommunity: Community?
    @State private var showingNewPostSheet = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Community selector
                CommunityTabBar(
                    communities: socialManager.communities,
                    selectedCommunity: $selectedCommunity
                )
                
                // Social feed
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Trending topics section
                        if !socialManager.trendingTopics.isEmpty {
                            TrendingTopicsSection(
                                topics: socialManager.trendingTopics
                            )
                        }
                        
                        // Main feed
                        ForEach(filteredMessages) { message in
                            SocialMessageCard(
                                message: message,
                                onLike: { 
                                    await likeMessage(message)
                                },
                                onShare: {
                                    await shareMessage(message)
                                },
                                onComment: {
                                    showComments(for: message)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .refreshable {
                    await refreshFeed()
                }
            }
            .navigationTitle("Social")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewPostSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingNewPostSheet) {
                NewPostSheet(
                    communities: socialManager.communities,
                    onPost: createNewPost
                )
            }
        }
    }
    
    private var filteredMessages: [SocialMessage] {
        if let community = selectedCommunity {
            return socialManager.socialFeed.filter { message in
                // Filter by community - implementation depends on your data model
                return true
            }
        }
        return socialManager.socialFeed
    }
    
    private func likeMessage(_ message: SocialMessage) async {
        guard let community = selectedCommunity else { return }
        
        try? await socialManager.likeMessage(
            messageId: message.id,
            communityId: community.id
        )
    }
    
    private func shareMessage(_ message: SocialMessage) async {
        // Show community picker for sharing
        guard let targetCommunity = selectedCommunity else { return }
        
        try? await socialManager.shareMessage(
            messageId: message.id,
            to: targetCommunity.id
        )
    }
}

// Social message card with engagement features
struct SocialMessageCard: View {
    let message: SocialMessage
    let onLike: () async -> Void
    let onShare: () async -> Void
    let onComment: () -> Void
    
    @State private var hasLiked = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User header
            HStack {
                AsyncImage(url: URL(string: message.author.avatar ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("@\(message.author.username)")
                        .fontWeight(.semibold)
                    
                    Text(formatRelativeTime(message.timestamp))
                        .font(.