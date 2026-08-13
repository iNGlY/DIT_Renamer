import Foundation

@main
struct RenamerEngineProcessTests {
    static func main() throws {
        let bytesPerStream = 512 * 1024
        let script = "head -c \(bytesPerStream) /dev/zero; head -c \(bytesPerStream) /dev/zero >&2"
        let result = try RenamerEngine.runCommand(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", script],
            timeout: 5
        )

        precondition(result.status == 0)
        precondition(result.standardOutput.utf8.count == bytesPerStream)
        precondition(result.standardError.utf8.count == bytesPerStream)

        let timeoutStartedAt = ContinuousClock.now
        do {
            _ = try RenamerEngine.runCommand(
                executableURL: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", "trap '' TERM; while :; do :; done"],
                timeout: 0.1
            )
            preconditionFailure("A command ignoring SIGTERM must not survive the timeout")
        } catch {
            precondition(
                ContinuousClock.now - timeoutStartedAt < .seconds(4),
                "Timeout handling must confirm forced termination before returning"
            )
        }
        print("RenamerEngineProcessTests: PASS")
    }
}
