import FamilyControls
import SwiftUI

struct ContentView: View {
    @StateObject private var store = GroupStore()
    @State private var pickerGroupID: UUID?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(store.groups) { group in
                        GroupTile(
                            group: group,
                            onChange: store.update,
                            onDelete: { store.delete(group.id) },
                            onPick: { pickerGroupID = group.id }
                        )
                    }

                    AddGroupTile {
                        store.addGroup()
                    }
                }
                .padding(16)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Delay Please")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await store.requestAuthorization() }
                    } label: {
                        Image(systemName: store.isAuthorized ? "checkmark.circle" : "hourglass.circle")
                    }
                    .accessibilityLabel(store.isAuthorized ? "Screen Time allowed" : "Allow Screen Time")
                }
            }
            .safeAreaInset(edge: .top) {
                if !store.isAuthorized || store.errorMessage != nil {
                    StatusStrip(
                        isAuthorized: store.isAuthorized,
                        message: store.errorMessage,
                        requestAuthorization: {
                            Task { await store.requestAuthorization() }
                        }
                    )
                }
            }
        }
        .familyActivityPicker(
            headerText: "Choose apps and websites",
            footerText: "Selected items use the delay and limit in this group.",
            isPresented: pickerPresented,
            selection: activeSelection
        )
        .task {
            store.refreshAuthorization()
        }
    }

    private var pickerPresented: Binding<Bool> {
        Binding(
            get: { pickerGroupID != nil },
            set: { isPresented in
                if !isPresented {
                    pickerGroupID = nil
                }
            }
        )
    }

    private var activeSelection: Binding<FamilyActivitySelection> {
        Binding(
            get: {
                guard let pickerGroupID else { return FamilyActivitySelection() }
                return store.group(with: pickerGroupID)?.selection ?? FamilyActivitySelection()
            },
            set: { selection in
                guard let pickerGroupID else { return }
                store.updateSelection(selection, for: pickerGroupID)
            }
        )
    }
}

private struct StatusStrip: View {
    let isAuthorized: Bool
    let message: String?
    let requestAuthorization: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(message ?? "Screen Time permission needed")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 8)

            if !isAuthorized {
                Button("Allow", action: requestAuthorization)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

private struct GroupTile: View {
    let group: DelayGroup
    let onChange: (DelayGroup) -> Void
    let onDelete: () -> Void
    let onPick: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                TextField("Group", text: binding(\.name))
                    .font(.subheadline.weight(.semibold))
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete group")
            }

            Button(action: onPick) {
                HStack(spacing: 8) {
                    Image(systemName: "app.badge")
                    Text(selectionSummary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.bordered)
            .font(.caption)

            VStack(spacing: 8) {
                NumberField(
                    title: "Wait",
                    suffix: "min",
                    value: binding(\.delayMinutes)
                )

                NumberField(
                    title: "Use",
                    suffix: "min",
                    value: binding(\.usageMinutes)
                )
            }

            HStack {
                Text("Color")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                ColorPicker(
                    "Block color",
                    selection: Binding(
                        get: { Color(uiColor: group.backgroundColor.uiColor) },
                        set: { newColor in
                            var updated = group
                            updated.backgroundColor = ShieldColor(color: newColor)
                            onChange(updated.normalized())
                        }
                    ),
                    supportsOpacity: false
                )
                .labelsHidden()
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var selectionSummary: String {
        let count = group.selection.applicationTokens.count
            + group.selection.categoryTokens.count
            + group.selection.webDomainTokens.count
        return count == 0 ? "Choose" : "\(count)"
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<DelayGroup, Value>) -> Binding<Value> {
        Binding(
            get: { group[keyPath: keyPath] },
            set: { newValue in
                var updated = group
                updated[keyPath: keyPath] = newValue
                onChange(updated.normalized())
            }
        )
    }
}

private struct NumberField: View {
    let title: String
    let suffix: String
    @Binding var value: Int

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 34, alignment: .leading)
            Spacer()
            TextField(title, value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 34)
            Text(suffix)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .font(.caption)
    }
}

private struct AddGroupTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2)
                .frame(maxWidth: .infinity, minHeight: 96)
        }
        .buttonStyle(.plain)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel("Create group")
    }
}
