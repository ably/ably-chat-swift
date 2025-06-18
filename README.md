![Ably Chat Swift Header](images/SwiftChatSDK-github.png)
![CocoaPods](https://img.shields.io/cocoapods/v/Ably.svg)
![SPM Swift Compatibility](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fably%2Fably-cocoa%2Fbadge%3Ftype%3Dswift-versions)
![License](https://badgen.net/github/license/3scale/saas-operator)

---

# Ably Chat Swift SDK

Ably Chat is a set of purpose-built APIs for a host of chat features enabling you to create 1:1, 1:Many, Many:1 and Many:Many chat rooms for any scale. It is designed to meet a wide range of chat use cases, such as livestreams, in-game communication, customer support, or social interactions in SaaS products. Built on [Ably's](https://ably.com/) core service, it abstracts complex details to enable efficient chat architectures.

---

## Getting started

Everything you need to get started with Ably:

* [About Ably Chat.](https://ably.com/docs/chat)
* [Getting started with Ably Chat in Swift.](https://ably.com/docs/chat/getting-started/swift)
* Play with the [livestream chat demo.](https://ably-livestream-chat-demo.vercel.app/)

---

## Supported Platforms

Ably aims to support a wide range of platforms. If you experience any compatibility issues, open an issue in the repository or contact [Ably support](https://ably.com/support).

This SDK supports the following platforms:

| Platform | Support      |
|----------|--------------|
| iOS      | >= 14.0      |
| macOS    | >= 11.0      |
| tvOS     | >= 14.0      |

> [!NOTE]
> Xcode v16.1 or later is required.

> [!IMPORTANT]
> SDK versions <  1.2.24 will be [deprecated](https://ably.com/docs/platform/deprecate/protocol-v1) from November 1, 2025.

---

## Usage

You will need the following prerequisites:

- An Ably account

  - You can [sign up](https://ably.com/signup) to the generous free tier.

- An Ably API key
  - Use the default or create a new API key in an app within
    your [Ably account dashboard](https://ably.com/dashboard).
  - Make sure your API key has the
    following [capabilities](https://ably.com/docs/auth/capabilities): `publish`, `subscribe`, `presence`, `history` and
    `channel-metadata`.

To instantiate the Chat SDK, create an [Ably client](https://ably.com/docs/getting-started/setup) and pass it into the Chat constructor:

```swift
import Ably
import AblyChat

let realtimeOptions = ARTClientOptions()
realtimeOptions.key = "<API_KEY>"
realtimeOptions.clientId = "<clientId>"
let realtime = ARTRealtime(options: realtimeOptions)
let chatClient = DefaultChatClient(realtime: realtime, clientOptions: nil)
```

You can use [basic authentication](https://ably.com/docs/auth/basic) i.e. the API Key directly for testing purposes,
however it is strongly recommended that you use [token authentication](https://ably.com/docs/auth/token) in production
environments.

To use Chat you must also set a [`clientId`](https://ably.com/docs/auth/identified-clients) so that users are
identifiable.

## Example app

This repository contains an example app, written using SwiftUI, which demonstrates how to use the SDK. The code for this app is in the [`Example`](Example) directory.

In order to allow the app to use modern SwiftUI features, it supports the following OS versions:

- macOS 14 and above
- iOS 17 and above
- tvOS 17 and above

To run the app, open the `AblyChat.xcworkspace` workspace in Xcode and run the `AblyChatExample` target. If you wish to run it on an iOS or tvOS device, you’ll need to set up code signing.

## Contributing

For guidance on how to contribute to this project, see the [contributing guidelines](CONTRIBUTING.md).

## Support, feedback and troubleshooting

Please visit http://support.ably.com/ for access to our knowledge base and to ask for any assistance. You can also view
the community reported [Github issues](https://github.com/ably/ably-chat-swift/issues) or raise one yourself.

To see what has changed in recent versions, see the [changelog](CHANGELOG.md).

[Share feedback or request](https://forms.gle/mBw9M53NYuCBLFpMA) a new feature.
