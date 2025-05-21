//
//  SettingsView.swift
//  TrackMe
//
//  Created by Quang Huy on 08/05/2025.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @State private var selectedTab: Tab = .general
    @State private var hoverGeneral = false
    @State private var hoverNotifications = false
    
    @StateObject private var viewModel: SettingsViewModel

    init(context: ModelContext) {
        _viewModel = StateObject(
            wrappedValue: SettingsViewModel(context: context)
        )
    }

    enum Tab {
        case general
        case notifications
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content Section
            if selectedTab == .general {
                generalSettings
            } else if selectedTab == .notifications {
                notificationsSettings
            }

            Spacer()
        }
        .frame(width: 450, height: 550)
        .padding()
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                HStack(spacing: 1) {
                    toolbarButton(
                        systemName: "gearshape",
                        title: "General",
                        isSelected: selectedTab == .general,
                        isHovering: hoverGeneral,
                        onHoverChanged: { hoverGeneral = $0 },
                        action: { selectedTab = .general }
                    )
                    
                    toolbarButton(
                        systemName: "bell",
                        title: "Notifications",
                        isSelected: selectedTab == .notifications,
                        isHovering: hoverNotifications,
                        onHoverChanged: { hoverNotifications = $0 },
                        action: { selectedTab = .notifications }
                    )
                }
            }
        }
    }

    // General Settings Content
    private var generalSettings: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "target")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    Text("Manage Your Focus Areas")
                        .font(.headline)
                }

                // List of focus items
                List {
                    ForEach(viewModel.focusOptions) { focus in
                        HStack {
                            Text(focus.focusName)
                            Spacer()
                            Button(action: {
                                if let index = viewModel.focusOptions.firstIndex(of: focus) {
                                    viewModel.deleteFocus(at: IndexSet([index]))
                                }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        viewModel.deleteFocus(at: indexSet)
                    }
                }
                .listStyle(SidebarListStyle())

                // Add new focus
                HStack {
                    TextField("New Focus Name", text: $viewModel.newFocusName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: {
                        viewModel.addFocus()
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(viewModel.newFocusName.isEmpty)
                }
            }
            .padding(.horizontal)
        }
    }

    // Notifications Settings Content
    private var notificationsSettings: some View {
        VStack {
            Text("Notifications Settings")
                .font(.headline)
                .padding()
            Spacer()
        }
    }
    
    @ViewBuilder
    private func toolbarButton(
        systemName: String,
        title: String,
        isSelected: Bool,
        isHovering: Bool,
        onHoverChanged: @escaping (Bool) -> Void,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack() {
                Image(systemName: systemName)
                    .font(.system(size: 20))
                Text(title)
                    .font(.subheadline)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected || isHovering
                            ? Color.gray.opacity(0.1) : Color.clear
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .foregroundColor(isSelected ? .blue : .primary)
        .onHover(perform: onHoverChanged)      // drive hover state
    }
}

#Preview("Settings View Preview") {
    let container = try! ModelContainer(for: Focus.self)
    let context = ModelContext(container)
    SettingsView(context: context)
}
