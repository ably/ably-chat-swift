# Ably Chat Swift SDK Example App

This is a simple app that demonstrates the following features:

- sending and receiving messages
- editing and deleting messages
- reacting to messages
- sending room-level reactions
- loading message history

To run the app, open the parent directory's `AblyChat.xcworkspace` workspace in Xcode and run the `AblyChatExample` target. If you wish to run it on an iOS or tvOS device, you’ll need to set up code signing.

By default, the example app uses a mock implementation of the Chat SDK. To switch to using the real SDK, change the `Environment.current` variable in `ContentView.swift` to `.live` and supply your Ably API key and a `clientID`.

In order to allow the app to use modern SwiftUI features, it supports the following OS versions:

- macOS 14 and above
- iOS 17 and above
- tvOS 17 and above

> [!NOTE]
> On tvOS, the app currently does not allow text input (that is, sending or editing of messages).
