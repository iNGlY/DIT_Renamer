import Foundation

@main
@MainActor
struct AutomaticRenameQueueTests {
    static func main() async {
        let queue = AutomaticRenameQueue()
        let first = UUID()
        let second = UUID()
        var started: [UUID] = []
        var completed: [UUID] = []
        var concurrentOperations = 0
        var maximumConcurrentOperations = 0

        let operation: @MainActor (UUID) async -> Void = { candidateID in
            started.append(candidateID)
            concurrentOperations += 1
            maximumConcurrentOperations = max(maximumConcurrentOperations, concurrentOperations)
            try? await Task.sleep(nanoseconds: 80_000_000)
            concurrentOperations -= 1
            completed.append(candidateID)
        }

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
        precondition(!queue.isProcessing && queue.pendingCount == 0, "The automatic queue must drain completely")

        let third = UUID()
        queue.enqueue(third, operation: operation)
        let secondDeadline = Date().addingTimeInterval(3)
        while (queue.isProcessing || queue.pendingCount > 0) && Date() < secondDeadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        precondition(completed.last == third, "The queue must restart cleanly after an earlier drain")

        print("AutomaticRenameQueueTests: PASS")
    }
}
