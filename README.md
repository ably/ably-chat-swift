# Ably Chat SDK for Swift

<p style="text-align: left">
    <img src="https://badgen.net/github/license/3scale/saas-operator" alt="License" />
    <img src="https://img.shields.io/badge/version-0.1.0--SNAPSHOT-2ea44f" alt="version: 0.1.0-SNAPSHOT" />
</p>

Ably Chat is a set of purpose-built APIs for a host of chat features enabling you to create 1:1, 1:Many, Many:1 and Many:Many chat rooms for
any scale. It is designed to meet a wide range of chat use cases, such as livestreams, in-game communication, customer support, or social
interactions in SaaS products. Built on [Ably's](https://ably.com/) core service, it abstracts complex details to enable efficient chat
architectures.

Get started using the [📚 documentation](https://ably.com/docs/products/chat).

![Ably Chat Header](/images/ably-chat-github-header.png)

## Supported Platforms

- macOS 11 and above
- iOS 14 and above
- tvOS 14 and above

## Requirements

Xcode 16 or later.

## Installation

The SDK is distributed as a Swift package and can hence be installed using Xcode (search for `github.com/ably/ably-chat-swift` package) or by adding it as a dependency in your package’s `Package.swift`:

```swift
.package(url: "https://github.com/ably/ably-chat-swift", from: "0.1.0")
```

## Supported chat features

This project is under development so we will be incrementally adding new features. At this stage, you'll find APIs for the following chat
features:

- Chat rooms for 1:1, 1:many, many:1 and many:many participation.
- Sending and receiving chat messages.
- Online status aka presence of chat participants.
- Chat room occupancy, i.e total number of connections and presence members.
- Typing indicators
- Room-level reactions (ephemeral at this stage)

If there are other features you'd like us to prioritize, please [let us know](https://forms.gle/mBw9M53NYuCBLFpMA).

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

## Contributing

For guidance on how to contribute to this project, see the [contributing guidelines](CONTRIBUTING.md).

## Support, feedback and troubleshooting

Please visit http://support.ably.com/ for access to our knowledge base and to ask for any assistance. You can also view
the community reported [Github issues](https://github.com/ably/ably-chat-swift/issues) or raise one yourself.

To see what has changed in recent versions, see the [changelog](CHANGELOG.md).

[Share feedback or request](https://forms.gle/mBw9M53NYuCBLFpMA) a new feature.
