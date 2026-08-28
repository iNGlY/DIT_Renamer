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

        Publishers.CombineLatest3(volumeMonitor.$volumes, ignoredVolumes.$paths, ignoredVolumes.$rules)
            .receive(on: RunLoop.main)
            .sink { [weak approvals] volumes, ignoredPaths, ignoredRules in
                let activeVolumes = MenuBarVolumeFilter.visibleVolumes(
                    volumes,
                    ignoredPaths: ignoredPaths,
                    ignoredRules: ignoredRules
                )
                approvals?.setExcludedMountPaths(Set(volumes.filter { !activeVolumes.contains($0) }.map(\.path)))
                approvals?.refresh(volumes: activeVolumes)
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(approvals.$pendingCandidates, approvals.$automaticCandidateIDs)
            .receive(on: RunLoop.main)
            .sink { [weak approvals, weak attentionCenter] _, _ in
                attentionCenter?.reconcile(candidates: approvals?.reviewCandidates ?? [])
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
        volumeMonitor.refreshVolumes { [weak self] latestVolumes in
            guard let self else { return }
            self.approvals.rescan(
                volumes: latestVolumes.filter { !self.ignoredVolumes.isIgnored($0) }
            )
        }
    }

    func refreshFilters() {
        volumeMonitor.refreshVolumes()
    }
}
