import ArgumentParser

enum Configuration: String, CaseIterable {
    case debug
    case release
}

extension Configuration: ExpressibleByArgument {
    init?(argument: String) {
        self.init(rawValue: argument)
    }
}
