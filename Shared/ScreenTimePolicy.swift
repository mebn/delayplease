import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

enum ScreenTimePolicy {
    static func lock(groups: [DelayGroup]) {
        for group in groups {
            shield(group)
        }
    }

    static func shield(_ group: DelayGroup) {
        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(group.storeName))
        apply(selection: group.selection, to: store)
        clearCountdown(groupID: group.id)
    }

    static func unlockAfterDelay(for group: DelayGroup, completion: @escaping () -> Void) {
        let now = Date()
        let unlocksAt = now.addingTimeInterval(TimeInterval(group.delayMinutes * 60))
        let relocksAt = unlocksAt.addingTimeInterval(TimeInterval(group.usageMinutes * 60))
        saveCountdown(CountdownState(groupID: group.id, unlocksAt: unlocksAt, relocksAt: relocksAt))

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .seconds(group.delayMinutes * 60)) {
            unshield(group)
            startUsageMonitor(for: group)
            completion()
        }
    }

    static func unshield(_ group: DelayGroup) {
        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(group.storeName))
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
    }

    static func clearGroup(id: UUID) {
        guard let group = loadGroups().first(where: { $0.id == id }) else { return }
        unshield(group)
        clearCountdown(groupID: id)
        DeviceActivityCenter().stopMonitoring([DeviceActivityName(group.activityName)])
    }

    static func group(for application: ApplicationToken) -> DelayGroup? {
        loadGroups().first { group in
            group.selection.applicationTokens.contains(application)
        }
    }

    static func group(for category: ActivityCategoryToken) -> DelayGroup? {
        loadGroups().first { group in
            group.selection.categoryTokens.contains(category)
        }
    }

    static func group(for webDomain: WebDomainToken) -> DelayGroup? {
        loadGroups().first { group in
            group.selection.webDomainTokens.contains(webDomain)
        }
    }

    static func group(for activity: DeviceActivityName) -> DelayGroup? {
        loadGroups().first { group in
            group.activityName == activity.rawValue
        }
    }

    static func countdown(for groupID: UUID) -> CountdownState? {
        guard
            let data = defaults?.data(forKey: AppConstants.countdownKeyPrefix + groupID.uuidString),
            let state = try? JSONDecoder().decode(CountdownState.self, from: data)
        else {
            return nil
        }
        return state
    }

    static func activeCountdown() -> CountdownState? {
        loadGroups()
            .compactMap { countdown(for: $0.id) }
            .filter { $0.unlocksAt > Date() }
            .sorted { $0.unlocksAt < $1.unlocksAt }
            .first
    }

    static func formattedCountdownText(for group: DelayGroup) -> String {
        guard let countdown = countdown(for: group.id), countdown.unlocksAt > Date() else {
            return "\(group.delayMinutes) min wait. \(group.usageMinutes) min access."
        }

        let seconds = max(0, Int(countdown.unlocksAt.timeIntervalSinceNow.rounded()))
        let minutesPart = seconds / 60
        let secondsPart = seconds % 60
        return String(format: "%02d:%02d until unlock", minutesPart, secondsPart)
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.appGroupID)
    }

    private static func loadGroups() -> [DelayGroup] {
        GroupPersistence.loadGroups()
    }

    private static func apply(selection: FamilyActivitySelection, to store: ManagedSettingsStore) {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    }

    private static func startUsageMonitor(for group: DelayGroup) {
        let threshold = DateComponents(minute: group.usageMinutes)
        let event: DeviceActivityEvent
        if #available(iOS 17.4, *) {
            event = DeviceActivityEvent(
                applications: group.selection.applicationTokens,
                categories: group.selection.categoryTokens,
                webDomains: group.selection.webDomainTokens,
                threshold: threshold,
                includesPastActivity: false
            )
        } else {
            event = DeviceActivityEvent(
                applications: group.selection.applicationTokens,
                categories: group.selection.categoryTokens,
                webDomains: group.selection.webDomainTokens,
                threshold: threshold
            )
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        do {
            try DeviceActivityCenter().startMonitoring(
                DeviceActivityName(group.activityName),
                during: schedule,
                events: [DeviceActivityEvent.Name("usage"): event]
            )
        } catch {
            shield(group)
        }
    }

    private static func saveCountdown(_ state: CountdownState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults?.set(data, forKey: AppConstants.countdownKeyPrefix + state.groupID.uuidString)
    }

    private static func clearCountdown(groupID: UUID) {
        defaults?.removeObject(forKey: AppConstants.countdownKeyPrefix + groupID.uuidString)
    }
}
