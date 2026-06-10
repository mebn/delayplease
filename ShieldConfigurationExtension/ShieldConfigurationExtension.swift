import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        configuration(for: application.token.flatMap(ScreenTimePolicy.group(for:)))
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        configuration(for: application.token.flatMap(ScreenTimePolicy.group(for:)) ?? category.token.flatMap(ScreenTimePolicy.group(for:)))
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        configuration(for: webDomain.token.flatMap(ScreenTimePolicy.group(for:)))
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        configuration(for: webDomain.token.flatMap(ScreenTimePolicy.group(for:)) ?? category.token.flatMap(ScreenTimePolicy.group(for:)))
    }

    private func configuration(for group: DelayGroup?) -> ShieldConfiguration {
        let group = group ?? DelayGroup(name: "Blocked")
        let textColor = readableTextColor(for: group.backgroundColor.uiColor)

        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: group.backgroundColor.uiColor,
            icon: nil,
            title: ShieldConfiguration.Label(text: group.name, color: textColor),
            subtitle: ShieldConfiguration.Label(text: ScreenTimePolicy.formattedCountdownText(for: group), color: textColor),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Start countdown", color: textColor),
            primaryButtonBackgroundColor: textColor.withAlphaComponent(0.16),
            secondaryButtonLabel: nil
        )
    }

    private func readableTextColor(for backgroundColor: UIColor) -> UIColor {
        var red: CGFloat = 1
        var green: CGFloat = 1
        var blue: CGFloat = 1
        var alpha: CGFloat = 1
        backgroundColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luminance = (0.299 * red) + (0.587 * green) + (0.114 * blue)
        return luminance > 0.55 ? .black : .white
    }
}
