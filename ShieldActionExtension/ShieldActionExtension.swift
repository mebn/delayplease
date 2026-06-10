import ManagedSettings

final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action: action, group: ScreenTimePolicy.group(for: application), completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action: action, group: ScreenTimePolicy.group(for: category), completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action: action, group: ScreenTimePolicy.group(for: webDomain), completionHandler: completionHandler)
    }

    private func handle(action: ShieldAction, group: DelayGroup?, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        guard action == .primaryButtonPressed, let group else {
            completionHandler(.close)
            return
        }

        ScreenTimePolicy.unlockAfterDelay(for: group) {
            completionHandler(.none)
        }
    }
}
