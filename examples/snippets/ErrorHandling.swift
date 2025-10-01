//
//  ErrorHandling.swift
//  Ably Chat Swift SDK Examples
//
//  Robust error handling patterns including connection error handling, retry strategies, and offline queue management
//  This example demonstrates comprehensive error handling with Ably Chat
//

import AblyChat
import Ably
import Foundation

// MARK: - Error Types and Handling

/// Comprehensive error handling for Ably Chat operations
class ChatErrorHandler {
    
    // MARK: - Connection Error Handling
    
    /// Handle connection-related errors with appropriate retry strategies
    /// - Parameter error: The error that occurred
    /// - Returns: Recommended action to take
    static func handleConnectionError(_ error: Error) -> ErrorRecoveryAction {
        if let artError = error as? ARTErrorInfo {
            print("🔍 Analyzing ARTErrorInfo:")
            print("   Code: \(artError.code)")
            print("   Status: \(artError.statusCode)")
            print("   Message: \(artError.message)")
            print("   Domain: \(artError.domain)")
            
            // Handle specific error codes
            switch artError.code {
            case 40140: // Token expired
                return .refreshAuth
            case 40150: // Token invalid
                return .refreshAuth
            case 80001, 80002: // Connection failed/lost
                return .retryWithBackoff
            case 90001: // Internal error
                return .retryAfterDelay(5.0)
            default:
                if artError.statusCode >= 500 {
                    return .retryWithBackoff // Server error
                } else if artError.statusCode >= 400 {
                    return .reportError // Client error
                } else {
                    return .retryAfterDelay(2.0)
                }
            }
        }
        
        // Handle other error types
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return .waitForConnection
            case .timedOut:
                return .retryWithBackoff
            case .cannotFindHost, .cannotConnectToHost:
                return .retryAfterDelay(10.0)
            default:
                return .retryAfterDelay(3.0)
            }
        }
        
        return .reportError
    }
    
    /// Handle chat-specific errors
    /// - Parameter error: Chat error
    /// - Returns: Recovery action
    static func handleChatError(_ error: Error) -> ErrorRecoveryAction {
        if let artError = error as? ARTErrorInfo {
            // Check if it's in the Ably Chat error domain
            if artError.domain == "AblyChatErrorDomain" {
                return handleAblyChatError(artError)
            }
        }
        
        return handleConnectionError(error)
    }
    
    /// Handle Ably Chat specific errors
    /// - Parameter error: ARTErrorInfo with chat domain
    /// - Returns: Recovery action
    private static func handleAblyChatError(_ error: ARTErrorInfo) -> ErrorRecoveryAction {
        print("🔍 Ably Chat Error:")
        print("   Code: \(error.code)")
        print("   Message: \(error.message)")
        
        switch error.code {
        case 40000: // Bad request
            return .reportError
        case 102_101: // Room in failed state
            return .recreateRoom
        case 102_102: // Room is releasing
            return .waitAndRetry(3.0)
        case 102_103: // Room is released
            return .recreateRoom
        case 102_106: // Room released before operation completed
            return .recreateRoom
        case 102_107: // Room in invalid state
            return .waitForRoomReady
        case 102_100: // Room discontinuity
            return .handleDiscontinuity
        case 42211: // Message rejected by before publish rule
            return .reportError
        case 42213: // Message rejected by moderation
            return .reportError
        default:
            return .retryAfterDelay(2.0)
        }
    }
}

// MARK: - Error Recovery Actions

/// Defines possible recovery actions for different error scenarios
enum ErrorRecoveryAction {
    case retryImmediately
    case retryAfterDelay(TimeInterval)
    case retryWithBackoff
    case refreshAuth
    case waitForConnection
    case waitAndRetry(TimeInterval)
    case recreateRoom
    case waitForRoomReady
    case handleDiscontinuity
    case reportError
    case abort
    
    var description: String {
        switch self {
        case .retryImmediately:
            return "Retry immediately"
        case .retryAfterDelay(let delay):
            return "Retry after \(delay) seconds"
        case .retryWithBackoff:
            return "Retry with exponential backoff"
        case .refreshAuth:
            return "Refresh authentication"
        case .waitForConnection:
            return "Wait for internet connection"
        case .waitAndRetry(let delay):
            return "Wait \(delay) seconds then retry"
        case .recreateRoom:
            return "Recreate room"
        case .waitForRoomReady:
            return "Wait for room to be ready"
        case .handleDiscontinuity:
            return "Handle discontinuity event"
        case .reportError:
            return "Report error to user"
        case .abort:
            return "Abort operation"
        }
    }
}

// MARK: - Retry Strategies

/// Implements various retry strategies with exponential backoff
class RetryStrategy {
    private let maxRetries: Int
    private let baseDelay: TimeInterval
    private let maxDelay: TimeInterval
    private let jitter: Bool
    
    init(maxRetries: Int = 3, baseDelay: TimeInterval = 1.0, maxDelay: TimeInterval = 30.0, jitter: Bool = true) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.jitter = jitter
    }
    
    /// Execute operation with retry logic
    /// - Parameter operation: Async operation to retry
    /// - Returns: Result of the operation
    func execute<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                let recoveryAction = ChatErrorHandler.handleChatError(error)
                print("❌ Attempt \(attempt + 1) failed: \(error)")
                print("   Recovery action: \(recoveryAction.description)")
                
                // Check if we should abort
                if case .abort = recoveryAction {
                    throw error
                }
                
                // If this is the last attempt, don't wait
                if attempt == maxRetries - 1 {
                    break
                }
                
                // Calculate delay for this attempt
                let delay = calculateDelay(for: attempt, action: recoveryAction)
                if delay > 0 {
                    print("⏳ Waiting \(delay) seconds before retry...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // All retries failed
        print("❌ All \(maxRetries) attempts failed")
        throw lastError ?? RetryError.allAttemptsFailed
    }
    
    /// Calculate delay for specific attempt and recovery action
    private func calculateDelay(for attempt: Int, action: ErrorRecoveryAction) -> TimeInterval {
        switch action {
        case .retryImmediately:
            return 0
        case .retryAfterDelay(let delay):
            return delay
        case .retryWithBackoff:
            let exponentialDelay = baseDelay * pow(2.0, Double(attempt))
            let cappedDelay = min(exponentialDelay, maxDelay)
            
            if jitter {
                // Add random jitter to prevent thundering herd
                let jitterAmount = cappedDelay * 0.1 * Double.random(in: 0...1)
                return cappedDelay + jitterAmount
            } else {
                return cappedDelay
            }
        case .waitAndRetry(let delay):
            return delay
        default:
            return baseDelay
        }
    }
}

// MARK: - Offline Queue Management

/// Manages operations while offline and replays them when connection is restored
@MainActor
class OfflineQueueManager: ObservableObject {
    @Published var isOnline = true
    @Published var queuedOperationsCount = 0
    
    private var queuedOperations: [QueuedOperation] = []
    private let maxQueueSize = 100
    private var connectionMonitor: ConnectionMonitor?
    
    init() {
        setupConnectionMonitoring()
    }
    
    /// Queue an operation for later execution
    /// - Parameter operation: Operation to queue
    func queueOperation(_ operation: QueuedOperation) {
        guard !isOnline else {
            // If online, execute immediately
            executeOperation(operation)
            return
        }
        
        // Add to queue
        queuedOperations.append(operation)
        queuedOperationsCount = queuedOperations.count
        
        print("📥 Queued operation: \(operation.type)")
        
        // Trim queue if too large
        if queuedOperations.count > maxQueueSize {
            let removed = queuedOperations.removeFirst()
            print("🗑️ Removed oldest queued operation: \(removed.type)")
        }
    }
    
    /// Process all queued operations when connection is restored
    func processQueuedOperations() async {
        guard isOnline && !queuedOperations.isEmpty else { return }
        
        print("🔄 Processing \(queuedOperations.count) queued operations...")
        
        let operations = queuedOperations
        queuedOperations.removeAll()
        queuedOperationsCount = 0
        
        for operation in operations {
            await executeOperation(operation)
            
            // Small delay between operations to avoid overwhelming
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        print("✅ Finished processing queued operations")
    }
    
    /// Execute a queued operation
    private func executeOperation(_ operation: QueuedOperation) {
        Task {
            do {
                try await operation.execute()
                print("✅ Executed queued operation: \(operation.type)")
            } catch {
                print("❌ Failed to execute queued operation \(operation.type): \(error)")
                
                // Re-queue if it's a temporary error
                let recoveryAction = ChatErrorHandler.handleChatError(error)
                if case .retryWithBackoff = recoveryAction {
                    queuedOperations.append(operation)
                    queuedOperationsCount = queuedOperations.count
                }
            }
        }
    }
    
    /// Setup connection monitoring
    private func setupConnectionMonitoring() {
        connectionMonitor = ConnectionMonitor { [weak self] isConnected in
            Task { @MainActor in
                let wasOnline = self?.isOnline ?? true
                self?.isOnline = isConnected
                
                if !wasOnline && isConnected {
                    // Connection restored
                    await self?.processQueuedOperations()
                }
            }
        }
    }
    
    /// Clear all queued operations
    func clearQueue() {
        queuedOperations.removeAll()
        queuedOperationsCount = 0
        print("🗑️ Cleared all queued operations")
    }
}

// MARK: - Queued Operation

/// Represents an operation that can be queued for offline execution
struct QueuedOperation {
    let id: UUID = UUID()
    let type: String
    let timestamp: Date = Date()
    let execute: () async throws -> Void
    
    init(type: String, execute: @escaping () async throws -> Void) {
        self.type = type
        self.execute = execute
    }
}

// MARK: - Connection Monitor

/// Simple connection monitor (in real app, use Network framework)
class ConnectionMonitor {
    private let onConnectionChange: (Bool) -> Void
    private var timer: Timer?
    
    init(onConnectionChange: @escaping (Bool) -> Void) {
        self.onConnectionChange = onConnectionChange
        startMonitoring()
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            // Simple connectivity check - in real app use Network framework
            let isConnected = self.checkConnectivity()
            self.onConnectionChange(isConnected)
        }
    }
    
    private func checkConnectivity() -> Bool {
        // Simplified connectivity check
        // In real implementation, use NWPathMonitor from Network framework
        return true // Assume connected for demo
    }
    
    deinit {
        timer?.invalidate()
    }
}

// MARK: - Resilient Chat Operations

/// Wrapper for chat operations with built-in error handling and retry logic
class ResilientChatOperations {
    private let room: Room
    private let retryStrategy: RetryStrategy
    private let offlineQueue: OfflineQueueManager
    
    init(room: Room, retryStrategy: RetryStrategy = RetryStrategy(), offlineQueue: OfflineQueueManager) {
        self.room = room
        self.retryStrategy = retryStrategy
        self.offlineQueue = offlineQueue
    }
    
    /// Send message with error handling and retry
    /// - Parameter params: Message parameters
    /// - Returns: Sent message
    func sendMessage(params: SendMessageParams) async throws -> Message {
        let operation = {
            try await self.room.messages.send(params: params)
        }
        
        // If offline, queue the operation
        if !offlineQueue.isOnline {
            let queuedOp = QueuedOperation(type: "sendMessage") {
                let _ = try await operation()
            }
            offlineQueue.queueOperation(queuedOp)
            
            // Return a placeholder message for optimistic UI
            throw OfflineError.operationQueued
        }
        
        // Execute with retry logic
        return try await retryStrategy.execute(operation)
    }
    
    /// Update message with error handling
    /// - Parameters:
    ///   - message: Message to update
    ///   - newText: New text content
    /// - Returns: Updated message
    func updateMessage(_ message: Message, newText: String) async throws -> Message {
        let operation = {
            let updatedMessage = message.copy(text: newText)
            return try await self.room.messages.update(
                newMessage: updatedMessage,
                description: nil,
                metadata: nil
            )
        }
        
        if !offlineQueue.isOnline {
            let queuedOp = QueuedOperation(type: "updateMessage") {
                let _ = try await operation()
            }
            offlineQueue.queueOperation(queuedOp)
            throw OfflineError.operationQueued
        }
        
        return try await retryStrategy.execute(operation)
    }
    
    /// Enter presence with error handling
    /// - Parameter data: Presence data
    func enterPresence(data: PresenceData? = nil) async throws {
        let operation = {
            if let data = data {
                try await self.room.presence.enter(data: data)
            } else {
                try await self.room.presence.enter()
            }
        }
        
        if !offlineQueue.isOnline {
            let queuedOp = QueuedOperation(type: "enterPresence") {
                try await operation()
            }
            offlineQueue.queueOperation(queuedOp)
            throw OfflineError.operationQueued
        }
        
        try await retryStrategy.execute(operation)
    }
    
    /// Send room reaction with error handling
    /// - Parameter params: Reaction parameters
    func sendRoomReaction(params: SendReactionParams) async throws {
        let operation = {
            try await self.room.reactions.send(params: params)
        }
        
        if !offlineQueue.isOnline {
            let queuedOp = QueuedOperation(type: "sendRoomReaction") {
                try await operation()
            }
            offlineQueue.queueOperation(queuedOp)
            throw OfflineError.operationQueued
        }
        
        try await retryStrategy.execute(operation)
    }
    
    /// Attach to room with comprehensive error handling
    func attachToRoom() async throws {
        let operation = {
            try await self.room.attach()
        }
        
        return try await retryStrategy.execute(operation)
    }
}

// MARK: - Error Recovery Manager

/// Manages error recovery across the entire chat application
@MainActor
class ErrorRecoveryManager: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .connected
    @Published var lastError: ErrorInfo?
    @Published var recoveryInProgress = false
    
    private let chatClient: ChatClient
    private var roomRecoveryTasks: [String: Task<Void, Never>] = [:]
    
    init(chatClient: ChatClient) {
        self.chatClient = chatClient
        setupConnectionMonitoring()
    }
    
    /// Handle error and attempt recovery
    /// - Parameters:
    ///   - error: Error to handle
    ///   - context: Context where error occurred
    func handleError(_ error: Error, context: String) {
        let errorInfo = ErrorInfo(
            error: error,
            context: context,
            timestamp: Date()
        )
        
        lastError = errorInfo
        
        print("🚨 Error in \(context): \(error)")
        
        let recoveryAction = ChatErrorHandler.handleChatError(error)
        print("🔧 Recovery action: \(recoveryAction.description)")
        
        executeRecoveryAction(recoveryAction, for: errorInfo)
    }
    
    /// Execute recovery action
    private func executeRecoveryAction(_ action: ErrorRecoveryAction, for errorInfo: ErrorInfo) {
        recoveryInProgress = true
        
        Task {
            defer { recoveryInProgress = false }
            
            switch action {
            case .refreshAuth:
                await attemptAuthRefresh()
            case .recreateRoom:
                await recreateRoomsIfNeeded()
            case .handleDiscontinuity:
                await handleDiscontinuityEvents()
            case .waitForConnection:
                await waitForConnectionRestore()
            case .retryAfterDelay(let delay):
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                await retryLastOperation()
            default:
                print("ℹ️ Recovery action \(action.description) requires manual handling")
            }
        }
    }
    
    /// Attempt to refresh authentication
    private func attemptAuthRefresh() async {
        print("🔄 Attempting auth refresh...")
        // Implementation would depend on your auth system
        // This is a placeholder for the actual refresh logic
        connectionStatus = .reconnecting
        
        // Simulate auth refresh
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        connectionStatus = .connected
        
        print("✅ Auth refresh completed")
    }
    
    /// Recreate rooms that are in failed state
    private func recreateRoomsIfNeeded() async {
        print("🔄 Recreating failed rooms...")
        // Implementation would recreate any rooms that are in failed state
        connectionStatus = .reconnecting
        
        // Simulate room recreation
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        connectionStatus = .connected
        
        print("✅ Room recreation completed")
    }
    
    /// Handle discontinuity events
    private func handleDiscontinuityEvents() async {
        print("🔄 Handling discontinuity events...")
        
        // Refresh message history, presence, etc.
        connectionStatus = .recovering
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        connectionStatus = .connected
        
        print("✅ Discontinuity handling completed")
    }
    
    /// Wait for connection to be restored
    private func waitForConnectionRestore() async {
        print("⏳ Waiting for connection restore...")
        connectionStatus = .disconnected
        
        // In real implementation, this would monitor actual connectivity
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        connectionStatus = .connected
        
        print("✅ Connection restored")
    }
    
    /// Retry last failed operation
    private func retryLastOperation() async {
        print("🔄 Retrying last operation...")
        
        // Implementation would retry the operation that failed
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        print("✅ Operation retry completed")
    }
    
    /// Setup connection monitoring
    private func setupConnectionMonitoring() {
        // Monitor chat client connection status
        // This would typically subscribe to connection events
        print("📡 Connection monitoring setup")
    }
    
    /// Clear error state
    func clearError() {
        lastError = nil
    }
}

// MARK: - Supporting Types

enum ConnectionStatus {
    case connected
    case connecting
    case reconnecting
    case recovering
    case disconnected
    case failed
    
    var description: String {
        switch self {
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .reconnecting: return "Reconnecting"
        case .recovering: return "Recovering"
        case .disconnected: return "Disconnected"
        case .failed: return "Failed"
        }
    }
    
    var isOperational: Bool {
        switch self {
        case .connected:
            return true
        default:
            return false
        }
    }
}

struct ErrorInfo {
    let error: Error
    let context: String
    let timestamp: Date
    let id: UUID = UUID()
    
    var description: String {
        "\(context): \(error.localizedDescription)"
    }
}

enum RetryError: LocalizedError {
    case allAttemptsFailed
    case maxRetriesExceeded
    
    var errorDescription: String? {
        switch self {
        case .allAttemptsFailed:
            return "All retry attempts failed"
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded"
        }
    }
}

enum OfflineError: LocalizedError {
    case operationQueued
    case queueFull
    
    var errorDescription: String? {
        switch self {
        case .operationQueued:
            return "Operation queued for when connection is restored"
        case .queueFull:
            return "Offline queue is full"
        }
    }
}

// MARK: - Complete Error Handling Example

/// Complete example demonstrating all error handling features
class CompleteErrorHandlingExample {
    
    func runErrorHandlingExample(room: Room) async {
        print("🚨 Running Error Handling Example")
        
        // 1. Setup error recovery infrastructure
        print("\n1. Setting up error recovery infrastructure:")
        
        let retryStrategy = RetryStrategy(maxRetries: 3, baseDelay: 1.0, maxDelay: 10.0)
        let offlineQueue = OfflineQueueManager()
        let resilientOps = ResilientChatOperations(
            room: room,
            retryStrategy: retryStrategy,
            offlineQueue: offlineQueue
        )
        
        // 2. Demonstrate retry strategies
        print("\n2. Testing retry strategies:")
        
        do {
            // This will succeed immediately
            let message = try await resilientOps.sendMessage(
                params: SendMessageParams(text: "Test message with retry handling")
            )
            print("✅ Message sent successfully: \(message.serial)")
        } catch {
            print("❌ Message send failed after retries: \(error)")
        }
        
        // 3. Test offline queue
        print("\n3. Testing offline queue:")
        
        // Simulate going offline
        await offlineQueue.queueOperation(
            QueuedOperation(type: "testMessage") {
                print("Executing queued test operation")
            }
        )
        
        // 4. Demonstrate error analysis
        print("\n4. Error analysis examples:")
        
        let sampleErrors: [Error] = [
            ARTErrorInfo(domain: "io.ably.cocoa", code: 40140, userInfo: [NSLocalizedDescriptionKey: "Token expired"]),
            ARTErrorInfo(domain: "AblyChatErrorDomain", code: 102_101, userInfo: [NSLocalizedDescriptionKey: "Room in failed state"]),
            URLError(.notConnectedToInternet)
        ]
        
        for error in sampleErrors {
            let action = ChatErrorHandler.handleChatError(error)
            print("   Error: \(error.localizedDescription)")
            print("   Action: \(action.description)")
        }
        
        // 5. Test room attachment with retry
        print("\n5. Testing room attachment with retry:")
        
        do {
            try await resilientOps.attachToRoom()
            print("✅ Room attached successfully")
        } catch {
            print("❌ Room attachment failed: \(error)")
        }
        
        // 6. Demonstrate graceful degradation
        print("\n6. Graceful degradation example:")
        
        // Test operations that might fail
        let operations = [
            ("Send message", { try await resilientOps.sendMessage(params: SendMessageParams(text: "Test")) }),
            ("Enter presence", { try await resilientOps.enterPresence() }),
            ("Send reaction", { try await resilientOps.sendRoomReaction(params: SendReactionParams(name: "👍")) })
        ]
        
        for (name, operation) in operations {
            do {
                try await operation()
                print("✅ \(name) succeeded")
            } catch OfflineError.operationQueued {
                print("📥 \(name) queued for later")
            } catch {
                print("❌ \(name) failed: \(error.localizedDescription)")
            }
        }
        
        // 7. Show queue status
        print("\n7. Queue status:")
        print("   Queued operations: \(offlineQueue.queuedOperationsCount)")
        print("   Online status: \(offlineQueue.isOnline)")
        
        // Wait a bit to see any async operations
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        print("✅ Error handling example completed!")
    }
}

/*
USAGE:

1. Basic error handling:
   do {
       let message = try await room.messages.send(params: params)
   } catch {
       let action = ChatErrorHandler.handleChatError(error)
       // Handle based on recovery action
   }

2. Retry strategy:
   let retryStrategy = RetryStrategy(maxRetries: 3, baseDelay: 1.0)
   let result = try await retryStrategy.execute {
       try await someOperation()
   }

3. Resilient operations:
   let offlineQueue = OfflineQueueManager()
   let resilientOps = ResilientChatOperations(
       room: room,
       retryStrategy: RetryStrategy(),
       offlineQueue: offlineQueue
   )
   
   try await resilientOps.sendMessage(params: params)

4. Error recovery manager:
   @StateObject private var errorRecovery = ErrorRecoveryManager(chatClient: chatClient)
   
   // In your error handling:
   errorRecovery.handleError(error, context: "sendMessage")

5. Offline queue management:
   @StateObject private var offlineQueue = OfflineQueueManager()
   
   .onChange(of: offlineQueue.isOnline) { isOnline in
       if isOnline {
           // Connection restored, queued operations will be processed
       }
   }

6. Connection status monitoring:
   .onChange(of: errorRecovery.connectionStatus) { status in
       switch status {
       case .connected:
           // Enable UI
       case .disconnected:
           // Show offline message
       case .recovering:
           // Show loading indicator
       }
   }

7. Comprehensive error handling pattern:
   func performChatOperation() async {
       do {
           try await chatOperation()
       } catch {
           errorRecovery.handleError(error, context: "operation")
           
           // Optionally show user-friendly error
           if case .reportError = ChatErrorHandler.handleChatError(error) {
               showErrorToUser(error)
           }
       }
   }

8. Complete example:
   Task {
       await CompleteErrorHandlingExample().runErrorHandlingExample(room: room)
   }

FEATURES COVERED:
- Connection error handling and analysis
- Retry strategies with exponential backoff
- Offline queue management
- Error recovery actions
- Room state error handling
- Authentication error handling
- Network connectivity monitoring
- Graceful degradation patterns
- Error reporting and logging
- SwiftUI integration for error states
- Comprehensive error classification
- Automatic error recovery mechanisms
*/