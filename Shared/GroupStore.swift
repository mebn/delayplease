import Combine
import FamilyControls
import Foundation

@MainActor
final class GroupStore: ObservableObject {
    @Published private(set) var groups: [DelayGroup] = []
    @Published private(set) var isAuthorized = false
    @Published var errorMessage: String?

    init() {
        groups = GroupPersistence.loadGroups()
        if groups.isEmpty {
            groups = [
                DelayGroup(name: "Social", delayMinutes: 1, usageMinutes: 10)
            ]
            persistAndApply()
        }
        refreshAuthorization()
    }

    func refreshAuthorization() {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        refreshAuthorization()
    }

    func addGroup() {
        groups.append(DelayGroup(name: "Group \(groups.count + 1)"))
        persistAndApply()
    }

    func delete(_ id: UUID) {
        ScreenTimePolicy.clearGroup(id: id)
        groups.removeAll { $0.id == id }
        persistAndApply()
    }

    func update(_ group: DelayGroup) {
        guard let index = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[index] = group.normalized()
        persistAndApply()
    }

    func updateSelection(_ selection: FamilyActivitySelection, for id: UUID) {
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return }
        groups[index].selection = selection
        persistAndApply()
    }

    func group(with id: UUID) -> DelayGroup? {
        groups.first { $0.id == id }
    }

    private func persistAndApply() {
        GroupPersistence.save(groups)
        ScreenTimePolicy.lock(groups: groups)
    }
}
