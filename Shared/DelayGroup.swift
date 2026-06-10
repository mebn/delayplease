import FamilyControls
import Foundation
import UIKit
import SwiftUI

enum AppConstants {
    static let appGroupID = "group.com.mebn.delayplease"
    static let groupsKey = "delayplease.groups"
    static let countdownKeyPrefix = "delayplease.countdown."
}

struct DelayGroup: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var selection: FamilyActivitySelection
    var delayMinutes: Int
    var usageMinutes: Int
    var delaySeconds: Int?
    var usageSeconds: Int?
    var backgroundColor: ShieldColor

    init(
        id: UUID = UUID(),
        name: String,
        selection: FamilyActivitySelection = FamilyActivitySelection(),
        delayMinutes: Int = 1,
        usageMinutes: Int = 10,
        delaySeconds: Int? = nil,
        usageSeconds: Int? = nil,
        backgroundColor: ShieldColor = .yellow
    ) {
        self.id = id
        self.name = name
        self.selection = selection
        self.delayMinutes = delayMinutes
        self.usageMinutes = usageMinutes
        self.delaySeconds = delaySeconds ?? delayMinutes * 60
        self.usageSeconds = usageSeconds ?? usageMinutes * 60
        self.backgroundColor = backgroundColor
    }

    var storeName: String {
        "group-\(id.uuidString)"
    }

    var activityName: String {
        "usage-\(id.uuidString)"
    }

    var delayDurationSeconds: Int {
        delaySeconds ?? delayMinutes * 60
    }

    var usageDurationSeconds: Int {
        usageSeconds ?? usageMinutes * 60
    }

    func normalized() -> DelayGroup {
        var copy = self
        copy.name = copy.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if copy.name.isEmpty {
            copy.name = "Group"
        }
        copy.delaySeconds = min(max(copy.delayDurationSeconds, 1), 86_400)
        copy.usageSeconds = min(max(copy.usageDurationSeconds, 1), 86_400)
        copy.delayMinutes = max(1, Int(ceil(Double(copy.delaySeconds ?? 60) / 60)))
        copy.usageMinutes = max(1, Int(ceil(Double(copy.usageSeconds ?? 60) / 60)))
        copy.backgroundColor = .yellow
        return copy
    }
}

struct ShieldColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double

    static let yellow = ShieldColor(red: 1, green: 0.8, blue: 0)

    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(color: Color) {
        let uiColor = UIColor(color)
        var redValue: CGFloat = 1
        var greenValue: CGFloat = 1
        var blueValue: CGFloat = 1
        var alphaValue: CGFloat = 1

        uiColor.getRed(&redValue, green: &greenValue, blue: &blueValue, alpha: &alphaValue)

        red = Double(redValue)
        green = Double(greenValue)
        blue = Double(blueValue)
    }
}

struct CountdownState: Codable, Equatable {
    var groupID: UUID
    var unlocksAt: Date
    var relocksAt: Date?

    var isWaiting: Bool {
        Date() < unlocksAt
    }
}

enum GroupPersistence {
    static func loadGroups() -> [DelayGroup] {
        guard
            let data = UserDefaults(suiteName: AppConstants.appGroupID)?.data(forKey: AppConstants.groupsKey),
            let groups = try? JSONDecoder().decode([DelayGroup].self, from: data)
        else {
            return []
        }
        return groups.map { $0.normalized() }
    }

    static func save(_ groups: [DelayGroup]) {
        guard let data = try? JSONEncoder().encode(groups.map { $0.normalized() }) else { return }
        UserDefaults(suiteName: AppConstants.appGroupID)?.set(data, forKey: AppConstants.groupsKey)
    }
}
