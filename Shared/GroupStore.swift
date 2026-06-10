import Combine
import FamilyControls
import Foundation

@MainActor
final class GroupStore: ObservableObject {
    @Published private(set) var groups: [DelayGroup] = []
    @Published private(set) var authorizationStatus: AuthorizationStatus
    @Published private(set) var isRequestingAuthorization = false
    @Published private(set) var hasRequestedAuthorization = false
    @Published private(set) var isAuthorized = false
    @Published var errorMessage: String?

    init() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        let loadedGroups = GroupPersistence.loadGroups()

        if let firstGroup = loadedGroups.first {
            groups = [firstGroup]
        } else {
            groups = [
                DelayGroup(name: "Delay", delayMinutes: 1, usageMinutes: 10)
            ]
        }

        refreshAuthorization()
        persistAndApply()

        if isAuthorized {
            for oldGroup in loadedGroups.dropFirst() {
                ScreenTimePolicy.clearGroup(id: oldGroup.id)
            }
        }
    }

    var primaryGroup: DelayGroup {
        groups.first ?? DelayGroup(name: "Delay")
    }

    func refreshAuthorization() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        isAuthorized = authorizationStatus == .approved
    }

    func requestAuthorizationIfNeeded() async {
        refreshAuthorization()
        guard authorizationStatus == .notDetermined else { return }
        await requestAuthorization()
    }

    func requestAuthorization() async {
        guard !isRequestingAuthorization else { return }
        isRequestingAuthorization = true
        defer {
            isRequestingAuthorization = false
            hasRequestedAuthorization = true
            refreshAuthorization()
            persistAndApply()
        }

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updatePrimary(_ group: DelayGroup) {
        groups = [group.normalized()]
        persistAndApply()
    }

    func updatePrimary<Value>(_ keyPath: WritableKeyPath<DelayGroup, Value>, to value: Value) {
        var group = primaryGroup
        group[keyPath: keyPath] = value
        updatePrimary(group)
    }

    func updateSelection(_ selection: FamilyActivitySelection) {
        var group = primaryGroup
        group.selection = selection
        updatePrimary(group)
    }

    private func persistAndApply() {
        GroupPersistence.save(groups)
        guard isAuthorized else { return }
        ScreenTimePolicy.lock(groups: groups)
    }
}
