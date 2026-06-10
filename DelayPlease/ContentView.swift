import FamilyControls
import SwiftUI

struct ContentView: View {
    @StateObject private var store = GroupStore()
    @State private var isPickerPresented = false

    var body: some View {
        NavigationStack {
            Group {
                if store.isAuthorized {
                    homeForm
                } else if store.isRequestingAuthorization || (store.authorizationStatus == .notDetermined && !store.hasRequestedAuthorization) {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    AuthorizationRequiredView(
                        requestAuthorization: {
                            Task { await store.requestAuthorization() }
                        }
                    )
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Delay Please")
        }
        .familyActivityPicker(
            headerText: "Choose apps and websites",
            footerText: "Selected apps and websites use these delay settings.",
            isPresented: $isPickerPresented,
            selection: activeSelection
        )
        .task {
            await store.requestAuthorizationIfNeeded()
        }
    }

    private var homeForm: some View {
        Form {
            Section("App picker") {
                Button {
                    isPickerPresented = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "app.badge")
                            .frame(width: 24)
                        Text("Choose Apps and Websites")
                        Spacer()
                        Text(selectionSummary)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(.blue)
                }

                Text("Select the apps, categories, and websites that should be delayed. Websites can also be added by searching for them.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Time settings") {
                DatePicker(
                    "Wait",
                    selection: waitTime,
                    in: timeRange,
                    displayedComponents: .hourAndMinute
                )

                DatePicker(
                    "Use",
                    selection: useTime,
                    in: timeRange,
                    displayedComponents: .hourAndMinute
                )

                Text("Wait is how long access stays blocked before opening. Use is how long access stays available before it locks again.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var selectionSummary: String {
        let selection = store.primaryGroup.selection
        let count = selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
        return count == 0 ? "None" : "\(count) selected"
    }

    private var activeSelection: Binding<FamilyActivitySelection> {
        Binding(
            get: { store.primaryGroup.selection },
            set: { selection in
                store.updateSelection(selection)
            }
        )
    }

    private var waitTime: Binding<Date> {
        durationBinding(
            seconds: store.primaryGroup.delayDurationSeconds,
            setSeconds: { store.updatePrimary(\.delaySeconds, to: $0) }
        )
    }

    private var useTime: Binding<Date> {
        durationBinding(
            seconds: store.primaryGroup.usageDurationSeconds,
            setSeconds: { store.updatePrimary(\.usageSeconds, to: $0) }
        )
    }

    private var timeRange: ClosedRange<Date> {
        durationDate(for: 60)...durationDate(for: 86_340)
    }

    private func durationBinding(seconds: Int, setSeconds: @escaping (Int) -> Void) -> Binding<Date> {
        Binding(
            get: { durationDate(for: seconds) },
            set: { date in
                setSeconds(max(60, min(secondsSinceStartOfDay(for: date), 86_340)))
            }
        )
    }

    private func durationDate(for seconds: Int) -> Date {
        let clampedSeconds = max(60, min(seconds, 86_340))
        return Calendar.current.date(
            byAdding: .second,
            value: clampedSeconds,
            to: durationStartDate
        ) ?? durationStartDate
    }

    private func secondsSinceStartOfDay(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ((components.hour ?? 0) * 3600) + ((components.minute ?? 1) * 60)
    }

    private var durationStartDate: Date {
        Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date(timeIntervalSinceReferenceDate: 0)
    }
}

private struct AuthorizationRequiredView: View {
    let requestAuthorization: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "hourglass.circle")
                .font(.system(size: 46, weight: .regular))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Screen Time access is needed")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            Button("Grant Access", action: requestAuthorization)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
