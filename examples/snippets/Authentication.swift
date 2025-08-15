//
//  Authentication.swift
//  Ably Chat Swift SDK Examples
//
//  Authentication patterns including token authentication, API key usage, and custom authentication
//  This example demonstrates various ways to authenticate with Ably Chat
//

import AblyChat
import Ably
import Foundation

// MARK: - Authentication Methods

/// Demonstrates different authentication patterns for Ably Chat
class ChatAuthentication {
    
    // MARK: - API Key Authentication
    
    /// Basic API key authentication - simplest approach for development
    /// - Parameters:
    ///   - apiKey: Your Ably API key from the dashboard
    ///   - clientId: Unique identifier for this client
    /// - Returns: Configured ChatClient
    static func authenticateWithAPIKey(apiKey: String, clientId: String) -> ChatClient {
        // Create client options with API key
        let options = ARTClientOptions(key: apiKey)
        options.clientId = clientId
        
        // Optional: Set environment for sandbox testing
        // options.environment = "sandbox"
        
        let realtimeClient = ARTRealtime(options: options)
        
        return DefaultChatClient(
            realtime: realtimeClient,
            clientOptions: ChatClientOptions()
        )
    }
    
    /// API key authentication with custom environment
    /// - Parameters:
    ///   - apiKey: Your Ably API key
    ///   - clientId: Client identifier
    ///   - environment: Ably environment (production, sandbox, etc.)
    /// - Returns: Configured ChatClient
    static func authenticateWithAPIKeyAndEnvironment(
        apiKey: String,
        clientId: String,
        environment: String
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
    
    // MARK: - Token Authentication
    
    /// Token-based authentication - recommended for production
    /// - Parameters:
    ///   - token: JWT token or Ably token string
    ///   - clientId: Client identifier
    /// - Returns: Configured ChatClient
    static func authenticateWithToken(token: String, clientId: String) -> ChatClient {
        let options = ARTClientOptions()
        options.token = token
        options.clientId = clientId
        
        let realtimeClient = ARTRealtime(options: options)
        
        return DefaultChatClient(
            realtime: realtimeClient,
            clientOptions: ChatClientOptions()
        )
    }
    
    /// Token authentication with refresh callback
    /// - Parameters:
    ///   - initialToken: Initial token to start with
    ///   - clientId: Client identifier
    ///   - tokenRefreshBlock: Callback to refresh token when needed
    /// - Returns: Configured ChatClient
    static func authenticateWithTokenRefresh(
        initialToken: String,
        clientId: String,
        tokenRefreshBlock: @escaping (ARTTokenParams?, @escaping ARTTokenCallback) -> Void
    ) -> ChatClient {
        let options = ARTClientOptions()
        options.token = initialToken
        options.clientId = clientId
        options.authCallback = tokenRefreshBlock
        
        let realtimeClient = ARTRealtime(options: options)
        
        return DefaultChatClient(
            realtime: realtimeClient,
            clientOptions: ChatClientOptions()
        )
    }
    
    // MARK: - JWT Authentication
    
    /// JWT token authentication with custom claims
    /// - Parameters:
    ///   - jwtToken: JWT token with Ably-compatible claims
    ///   - clientId: Client identifier (should match JWT sub claim)
    /// - Returns: Configured ChatClient
    static func authenticateWithJWT(jwtToken: String, clientId: String) -> ChatClient {
        let options = ARTClientOptions()
        options.token = jwtToken
        options.clientId = clientId
        
        // JWT tokens are typically used with specific auth URLs
        // options.authUrl = URL(string: "https://your-auth-server.com/auth")
        
        let realtimeClient = ARTRealtime(options: options)
        
        return DefaultChatClient(
            realtime: realtimeClient,
            clientOptions: ChatClientOptions()
        )
    }
    
    // MARK: - Custom Authentication Server
    
    /// Authentication using your own auth server
    /// - Parameters:
    ///   - authURL: URL to your authentication endpoint
    ///   - clientId: Client identifier
    ///   - headers: Additional headers for auth request
    /// - Returns: Configured ChatClient
    static func authenticateWithAuthServer(
        authURL: URL,
        clientId: String,
        headers: [String: String]? = nil
    ) -> ChatClient {
        let options = ARTClientOptions()
        options.authUrl = authURL
        options.clientId = clientId
        
        // Add custom headers if provided
        if let headers = headers {
            options.authHeaders = headers
        }
        
        // Optional: Add auth parameters
        // options.authParams = ["user_id": clientId, "role": "user"]
        
        let realtimeClient = ARTRealtime(options: options)
        
        return DefaultChatClient(
            realtime: realtimeClient,
            clientOptions: ChatClientOptions()
        )
    }
    
    /// Authentication with custom auth callback
    /// - Parameters:
    ///   - clientId: Client identifier
    ///   - authCallback: Custom authentication logic
    /// - Returns: Configured ChatClient
    static func authenticateWithCustomCallback(
        clientId: String,
        authCallback: @escaping (ARTTokenParams?, @escaping ARTTokenCallback) -> Void
    ) -> ChatClient {
        let options = ARTClientOptions()
        options.clientId = clientId
        options.authCallback = authCallback
        
        let realtimeClient = ARTRealtime(options: options)
        
        return DefaultChatClient(
            realtime: realtimeClient,
            clientOptions: ChatClientOptions()
        )
    }
}

// MARK: - Authentication Examples

/// Practical examples of different authentication scenarios
class AuthenticationExamples {
    
    // MARK: - Development Authentication
    
    /// Simple development setup with API key
    func setupDevelopmentAuthentication() -> ChatClient {
        return ChatAuthentication.authenticateWithAPIKey(
            apiKey: "YOUR_ABLY_API_KEY",
            clientId: "dev-user-\(UUID().uuidString)"
        )
    }
    
    /// Sandbox testing authentication
    func setupSandboxAuthentication() -> ChatClient {
        return ChatAuthentication.authenticateWithAPIKeyAndEnvironment(
            apiKey: "YOUR_SANDBOX_API_KEY",
            clientId: "test-user-123",
            environment: "sandbox"
        )
    }
    
    // MARK: - Production Authentication
    
    /// Production token-based authentication
    func setupProductionAuthentication(userToken: String, userId: String) -> ChatClient {
        return ChatAuthentication.authenticateWithToken(
            token: userToken,
            clientId: userId
        )
    }
    
    /// Production authentication with token refresh
    func setupProductionWithRefresh(
        initialToken: String,
        userId: String,
        authService: AuthService
    ) -> ChatClient {
        return ChatAuthentication.authenticateWithTokenRefresh(
            initialToken: initialToken,
            clientId: userId
        ) { tokenParams, callback in
            // Refresh token using your auth service
            Task {
                do {
                    let newToken = try await authService.refreshToken()
                    callback(ARTTokenDetails(token: newToken), nil)
                } catch {
                    callback(nil, error as NSError)
                }
            }
        }
    }
    
    // MARK: - Server-Side Authentication
    
    /// Authentication using your auth server
    func setupServerAuthentication(userId: String, authToken: String) -> ChatClient {
        let authURL = URL(string: "https://your-app.com/api/ably/auth")!
        
        return ChatAuthentication.authenticateWithAuthServer(
            authURL: authURL,
            clientId: userId,
            headers: [
                "Authorization": "Bearer \(authToken)",
                "Content-Type": "application/json"
            ]
        )
    }
    
    /// Custom authentication with user context
    func setupCustomAuthentication(
        userId: String,
        userRole: String,
        sessionToken: String
    ) -> ChatClient {
        return ChatAuthentication.authenticateWithCustomCallback(
            clientId: userId
        ) { tokenParams, callback in
            // Custom authentication logic
            Task {
                do {
                    let authRequest = AuthRequest(
                        userId: userId,
                        role: userRole,
                        sessionToken: sessionToken
                    )
                    
                    let tokenResponse = try await self.authenticateUser(authRequest)
                    
                    let tokenDetails = ARTTokenDetails(token: tokenResponse.token)
                    callback(tokenDetails, nil)
                    
                } catch {
                    print("❌ Authentication failed: \(error)")
                    callback(nil, error as NSError)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Simulate user authentication with your backend
    private func authenticateUser(_ request: AuthRequest) async throws -> AuthResponse {
        // This would typically make an HTTP request to your auth server
        // For example purposes, we'll simulate a response
        
        guard !request.sessionToken.isEmpty else {
            throw AuthError.invalidSession
        }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        return AuthResponse(
            token: "simulated.jwt.token",
            expiresAt: Date().addingTimeInterval(3600) // 1 hour
        )
    }
}

// MARK: - Authentication Models

/// Authentication request model
struct AuthRequest {
    let userId: String
    let role: String
    let sessionToken: String
}

/// Authentication response model
struct AuthResponse {
    let token: String
    let expiresAt: Date
}

/// Authentication service protocol
protocol AuthService {
    func refreshToken() async throws -> String
    func validateToken(_ token: String) async throws -> Bool
}

/// Example auth service implementation
class DefaultAuthService: AuthService {
    private let authURL: URL
    private let apiKey: String
    
    init(authURL: URL, apiKey: String) {
        self.authURL = authURL
        self.apiKey = apiKey
    }
    
    func refreshToken() async throws -> String {
        var request = URLRequest(url: authURL.appendingPathComponent("refresh"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.refreshFailed
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        return authResponse.token
    }
    
    func validateToken(_ token: String) async throws -> Bool {
        var request = URLRequest(url: authURL.appendingPathComponent("validate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        
        return httpResponse.statusCode == 200
    }
}

// MARK: - Authentication Errors

enum AuthError: LocalizedError {
    case invalidSession
    case refreshFailed
    case networkError
    case invalidCredentials
    
    var errorDescription: String? {
        switch self {
        case .invalidSession:
            return "Invalid or expired session"
        case .refreshFailed:
            return "Failed to refresh authentication token"
        case .networkError:
            return "Network error during authentication"
        case .invalidCredentials:
            return "Invalid authentication credentials"
        }
    }
}

// MARK: - Authentication Manager

/// Complete authentication manager for production use
@MainActor
class ChatAuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private var chatClient: ChatClient?
    private var authService: AuthService?
    
    /// Initialize the authentication manager
    /// - Parameters:
    ///   - authService: Service for handling authentication
    func initialize(authService: AuthService) {
        self.authService = authService
    }
    
    /// Sign in with username and password
    /// - Parameters:
    ///   - username: User's username or email
    ///   - password: User's password
    func signIn(username: String, password: String) async throws {
        // 1. Authenticate with your backend
        let authRequest = try await authenticateWithBackend(username: username, password: password)
        
        // 2. Create Ably chat client with token
        chatClient = ChatAuthentication.authenticateWithTokenRefresh(
            initialToken: authRequest.token,
            clientId: authRequest.userId
        ) { [weak self] tokenParams, callback in
            Task { @MainActor in
                do {
                    guard let self = self,
                          let authService = self.authService else {
                        callback(nil, AuthError.invalidSession as NSError)
                        return
                    }
                    
                    let newToken = try await authService.refreshToken()
                    callback(ARTTokenDetails(token: newToken), nil)
                } catch {
                    callback(nil, error as NSError)
                }
            }
        }
        
        // 3. Update UI state
        currentUser = User(id: authRequest.userId, name: username)
        isAuthenticated = true
    }
    
    /// Sign out and cleanup
    func signOut() async {
        chatClient = nil
        currentUser = nil
        isAuthenticated = false
    }
    
    /// Get the current chat client
    func getChatClient() -> ChatClient? {
        return chatClient
    }
    
    // MARK: - Private Methods
    
    private func authenticateWithBackend(username: String, password: String) async throws -> AuthRequest {
        // Simulate backend authentication
        // In real app, this would make HTTP request to your auth API
        
        guard !username.isEmpty, !password.isEmpty else {
            throw AuthError.invalidCredentials
        }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        return AuthRequest(
            userId: "user_\(username)",
            role: "user",
            sessionToken: "session_\(UUID().uuidString)"
        )
    }
}

// MARK: - User Model

struct User {
    let id: String
    let name: String
}

// MARK: - Complete Authentication Example

/// Complete working authentication example
class CompleteAuthenticationExample {
    
    /// Run different authentication scenarios
    func runAuthenticationExamples() async {
        print("🔐 Running Authentication Examples")
        
        // Example 1: Development with API key
        print("\n1. Development Authentication:")
        let devClient = ChatAuthentication.authenticateWithAPIKey(
            apiKey: "YOUR_DEVELOPMENT_API_KEY",
            clientId: "dev-user-123"
        )
        print("✅ Development client created with clientId: \(devClient.clientID)")
        
        // Example 2: Production with token
        print("\n2. Production Token Authentication:")
        let prodClient = ChatAuthentication.authenticateWithToken(
            token: "your.jwt.token",
            clientId: "prod-user-456"
        )
        print("✅ Production client created with clientId: \(prodClient.clientID)")
        
        // Example 3: Custom auth server
        print("\n3. Auth Server Authentication:")
        guard let authURL = URL(string: "https://your-app.com/api/ably/auth") else { return }
        
        let serverClient = ChatAuthentication.authenticateWithAuthServer(
            authURL: authURL,
            clientId: "server-user-789",
            headers: ["Authorization": "Bearer your-app-token"]
        )
        print("✅ Server auth client created with clientId: \(serverClient.clientID)")
        
        // Example 4: Using authentication manager
        print("\n4. Authentication Manager:")
        let authManager = ChatAuthenticationManager()
        
        let authService = DefaultAuthService(
            authURL: authURL,
            apiKey: "your-api-key"
        )
        
        await authManager.initialize(authService: authService)
        
        do {
            try await authManager.signIn(username: "testuser", password: "password123")
            print("✅ User authenticated: \(authManager.currentUser?.name ?? "Unknown")")
            
            if let client = authManager.getChatClient() {
                print("✅ Chat client available with clientId: \(client.clientID)")
            }
            
            await authManager.signOut()
            print("✅ User signed out")
            
        } catch {
            print("❌ Authentication failed: \(error)")
        }
        
        print("\n🔐 Authentication examples completed!")
    }
}

/*
USAGE:

1. For simple development:
   let chatClient = ChatAuthentication.authenticateWithAPIKey(
       apiKey: "YOUR_API_KEY",
       clientId: "user123"
   )

2. For production with tokens:
   let chatClient = ChatAuthentication.authenticateWithToken(
       token: userToken,
       clientId: userId
   )

3. For SwiftUI with authentication manager:
   @StateObject private var authManager = ChatAuthenticationManager()
   
   .task {
       authManager.initialize(authService: yourAuthService)
   }
   
   Button("Sign In") {
       Task {
           try await authManager.signIn(username: username, password: password)
       }
   }

4. Run complete example:
   Task {
       await CompleteAuthenticationExample().runAuthenticationExamples()
   }

SECURITY NOTES:
- Never store API keys in client-side code for production
- Use token-based authentication for production apps
- Implement proper token refresh logic
- Validate tokens on your backend
- Use HTTPS for all authentication endpoints
*/