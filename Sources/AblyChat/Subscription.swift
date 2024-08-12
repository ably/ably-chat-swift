/// TODO: so what's the API here? there needs to be a way of purging the buffer, which I assume is what AsyncStream does when _somebody_ starts to iterate over it. I think this should just work the same as AsyncSequence; that you can have multiple consumers but they both drain it
/// TODO note that I wasn't able to do this as protocols
/// So, this works — both in that you don't need `try` in the loop and that it knows the element type. Why doesn’t it work with protocols? If
///  but this is no good because now we can't really mock this
public struct Subscription<Element>: Sendable, AsyncSequence {
    // TODO: explain, this is a workaround to allow us to write mocks
    public init<T: AsyncSequence>(mockAsyncSequence _: T) where T.Element == Element {
        fatalError("Not implemented")
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        // note that I’ve removed the `throws` here and that means we don't need a `try` in the loop
        public mutating func next() async -> Element? {
            fatalError("Not implemented")
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        fatalError("Not implemented")
    }
}
