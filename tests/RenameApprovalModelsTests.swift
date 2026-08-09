import Foundation

@main
struct RenameApprovalModelsTests {
    static func main() throws {
        let withSuffix = VolumeNameRequest(
            cameraLetter: "a",
            rollNumber: "003",
            reuseCount: 2,
            suffix: "_S",
            includeSuffix: true
        )
        let withoutSuffix = VolumeNameRequest(
            cameraLetter: "A",
            rollNumber: "003",
            reuseCount: 2,
            suffix: "_S",
            includeSuffix: false
        )

        let suffixName = try VolumeNameBuilder.build(withSuffix)
        let plainName = try VolumeNameBuilder.build(withoutSuffix)
        precondition(suffixName == "A003-2_S")
        precondition(plainName == "A003-2")

        do {
            _ = try VolumeNameBuilder.build(
                VolumeNameRequest(
                    cameraLetter: "AB",
                    rollNumber: "001",
                    reuseCount: 0,
                    suffix: nil,
                    includeSuffix: false
                )
            )
            preconditionFailure("Invalid camera letter was accepted")
        } catch VolumeNameError.invalidCameraLetter {
            // Expected.
        }

        do {
            _ = try VolumeNameBuilder.build(
                VolumeNameRequest(
                    cameraLetter: "A",
                    rollNumber: "1234567890",
                    reuseCount: 0,
                    suffix: "_S",
                    includeSuffix: true
                ),
                fileSystem: "exFAT"
            )
            preconditionFailure("An exFAT name longer than 11 characters was accepted")
        } catch VolumeNameError.tooLong {
            // Expected.
        }

        print("RenameApprovalModelsTests: PASS")
    }
}
