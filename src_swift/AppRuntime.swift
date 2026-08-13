import Combine
import Foundation

@MainActor
final class AppRuntime: ObservableObject {
    let volumeMonitor: VolumeMonitor
    let approvals: RenameApprovalCoordinator
    let ignoredVolumes: IgnoredVolumeStore
    let attentionCenter: OperatorAttentionCenter

    private var cancellables = Set<AnyCancellable>()

    init() {
        let volumeMonitor = VolumeMonitor()
        let approvals = RenameApprovalCoordinator.shared
        let ignoredVolumes = IgnoredVolumeStore.shared
        let attentionCenter = OperatorAttentionCenter.shared
        self.volumeMonitor = volumeMonitor
        self.approvals = approvals
        self.ignoredVolumes = ignoredVolumes
        self.attentionCenter = attentionCenter

        Publishers.CombineLatest(volumeMonitor.$volumes, ignoredVolumes.$paths)
            .receive(on: RunLoop.main)
            .sink { [weak approvals] volumes, ignoredPaths in
                approvals?.setExcludedMountPaths(ignoredPaths)
                approvals?.refresh(volumes: volumes.filter { !ignoredPaths.contains($0.path) })
            }
            .store(in: &cancellables)

        approvals.$pendingCandidates
            .receive(on: RunLoop.main)
            .sink { [weak attentionCenter] candidates in
                attentionCenter?.reconcile(candidates: candidates)
            }
            .store(in: &cancellables)

        approvals.$lastResult
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak attentionCenter] result in
                attentionCenter?.record(result: result)
            }
            .store(in: &cancellables)

        attentionCenter.refreshAuthorizationStatus()
        approvals.refresh(volumes: volumeMonitor.volumes)
    }

    func refreshAll() {
        volumeMonitor.refreshVolumes()
        approvals.rescan(volumes: volumeMonitor.volumes.filter { !ignoredVolumes.paths.contains($0.path) })
    }

    func refreshFilters() {
        volumeMonitor.refreshVolumes()
    }
}
