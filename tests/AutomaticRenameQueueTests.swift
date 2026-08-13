import Foundation

@main
@MainActor
struct AutomaticRenameQueueTests {
    static func main() async {
        precondition(AutomaticRenameQueue.defaultInitialStabilizationNanoseconds == 1_000_000_000)
        precondition(AutomaticRenameQueue.defaultInterOperationDelayNanoseconds == 1_000_000_000)
        let minimumGap: UInt64 = 120_000_000
        let queue = AutomaticRenameQueue(
            initialStabilizationNanoseconds: minimumGap,
            interOperationDelayNanoseconds: minimumGap
        )
        let first = UUID()
        let second = UUID()
        var started: [UUID] = []
        var startTimes: [ContinuousClock.Instant] = []
        var completed: [UUID] = []
        var concurrentOperations = 0
        var maximumConcurrentOperations = 0

        let operation: @MainActor (UUID) async -> Void = { candidateID in
            started.append(candidateID)
            startTimes.append(ContinuousClock.now)
            concurrentOperations += 1
            maximumConcurrentOperations = max(maximumConcurrentOperations, concurrentOperations)
            try? await Task.sleep(nanoseconds: 80_000_000)
            concurrentOperations -= 1
            completed.append(candidateID)
        }

        let enqueuedAt = ContinuousClock.now
        queue.enqueue(first, operation: operation)
        queue.enqueue(second, operation: operation)
        queue.enqueue(first, operation: operation)

        let deadline = Date().addingTimeInterval(3)
        while (queue.isProcessing || queue.pendingCount > 0) && Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        precondition(started == [first, second], "Two cards must execute in insertion order and duplicate mount events must be coalesced")
        precondition(completed == [first, second], "Both cards must complete automatically")
        precondition(maximumConcurrentOperations == 1, "Forced rename/remount operations must remain strictly sequential")
        precondition(
            startTimes[0] - enqueuedAt >= .nanoseconds(Int64(minimumGap)),
            "The first automatic rename must wait for a short simultaneous-card stabilization window"
        )
        precondition(
            startTimes[1] - startTimes[0] >= .nanoseconds(Int64(minimumGap + 80_000_000)),
            "Consecutive automatic renames must include a settling delay after the prior operation"
        )
        precondition(!queue.isProcessing && queue.pendingCount == 0, "The automatic queue must drain completely")

        let third = UUID()
        let thirdEnqueuedAt = ContinuousClock.now
        queue.enqueue(third, operation: operation)
        let secondDeadline = Date().addingTimeInterval(3)
        while (queue.isProcessing || queue.pendingCount > 0) && Date() < secondDeadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        precondition(completed.last == third, "The queue must restart cleanly after an earlier drain")
        precondition(
            startTimes.last! - thirdEnqueuedAt >= .nanoseconds(Int64(minimumGap)),
            "Every new queue cycle must apply the initial stabilization window"
        )

        print("AutomaticRenameQueueTests: PASS")
    }
}
