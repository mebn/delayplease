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
        let unlocksAt = now.addingTimeInterval(TimeInterval(group.delayDurationSeconds))
        let relocksAt = unlocksAt.addingTimeInterval(TimeInterval(group.usageDurationSeconds))
        saveCountdown(CountdownState(groupID: group.id, unlocksAt: unlocksAt, relocksAt: relocksAt))

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .seconds(group.delayDurationSeconds)) {
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
            return "\(formatDuration(group.delayDurationSeconds)) wait. \(formatDuration(group.usageDurationSeconds)) access."
        }

        let seconds = max(0, Int(countdown.unlocksAt.timeIntervalSinceNow.rounded()))
        return "\(formatClock(seconds)) until unlock"
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
        let threshold = durationComponents(for: group.usageDurationSeconds)
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

    private static func durationComponents(for seconds: Int) -> DateComponents {
        DateComponents(
            hour: seconds / 3600,
            minute: (seconds % 3600) / 60,
            second: seconds % 60
        )
    }

    private static func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) hr") }
        if minutes > 0 { parts.append("\(minutes) min") }
        if remainingSeconds > 0 || parts.isEmpty { parts.append("\(remainingSeconds) sec") }
        return parts.joined(separator: " ")
    }

    private static func formatClock(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
