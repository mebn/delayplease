import DeviceActivity

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        guard let group = ScreenTimePolicy.group(for: activity) else { return }
        ScreenTimePolicy.shield(group)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        guard let group = ScreenTimePolicy.group(for: activity) else { return }
        ScreenTimePolicy.shield(group)
    }
}
