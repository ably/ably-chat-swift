import Foundation

@available(macOS 14, *)
enum DestinationFetcher {
    static func fetchDeviceUDID(destinationPredicate: DestinationPredicate) async throws -> String {
        let simctlAvailableDevicesOutput = try await fetchSimctlAvailableDevicesOutput()

        let runtimeIdentifier = "com.apple.CoreSimulator.SimRuntime.\(destinationPredicate.runtime)"
        let deviceTypeIdentifier = "com.apple.CoreSimulator.SimDeviceType.\(destinationPredicate.deviceType)"

        let matchingDevices = (simctlAvailableDevicesOutput.devices[runtimeIdentifier] ?? []).filter { $0.deviceTypeIdentifier == deviceTypeIdentifier }

        guard !matchingDevices.isEmpty else {
            throw Error.simulatorLookupFailed(message: "Couldn’t find a simulator with runtime \(runtimeIdentifier) and device type \(deviceTypeIdentifier); available devices are \(simctlAvailableDevicesOutput.devices)")
        }

        guard matchingDevices.count == 1 else {
            throw Error.simulatorLookupFailed(message: "Found multiple simulators with runtime \(runtimeIdentifier) and device type \(deviceTypeIdentifier); matching devices are \(matchingDevices)")
        }

        return matchingDevices[0].udid
    }

    struct SimctlOutput: Codable {
        var devices: [String: [Device]]

        struct Device: Codable {
            var udid: String
            var deviceTypeIdentifier: String
        }
    }

    private static func fetchSimctlAvailableDevicesOutput() async throws -> SimctlOutput {
        let data = try await ProcessRunner.runAndReturnStdout(
            executableName: "xcrun",
            arguments: ["simctl", "list", "--json", "devices", "available"],
        )

        return try JSONDecoder().decode(SimctlOutput.self, from: data)
    }
}
