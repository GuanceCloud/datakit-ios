//
//  SwiftUIDemoView.swift
//  SwiftApp
//
//  Created by hulilei on 2026/5/12.
//  Copyright © 2026 GuanceCloud. All rights reserved.
//

import SwiftUI

struct SwiftUIDemoView: View {
    @State private var selectedStatus = DemoStatus.normal
    @State private var isEnabled = true
    @State private var sampleRate = 0.75
    @State private var selectedTab = DemoTab.overview

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                segmentedControl
                summaryGrid
                componentList
                formPreview
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("SwiftUI Demo")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "swift")
                    .font(.largeTitle)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("SwiftUI Components")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Basic views, controls, and layout examples")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Text("This page is intentionally UI-only. SDK API examples remain in the existing Swift pages.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var segmentedControl: some View {
        Picker("Content", selection: $selectedTab) {
            ForEach(DemoTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            SummaryCard(title: "Text", value: "Label", systemImage: "textformat", tint: .blue)
            SummaryCard(title: "Image", value: "SF Symbol", systemImage: "photo", tint: .purple)
            SummaryCard(title: "Control", value: isEnabled ? "On" : "Off", systemImage: "switch.2", tint: .green)
            SummaryCard(title: "Progress", value: "\(Int(sampleRate * 100))%", systemImage: "chart.line.uptrend.xyaxis", tint: .orange)
        }
    }

    private var componentList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Display Components", subtitle: selectedTab.subtitle)

            ForEach(DemoComponent.components(for: selectedTab)) { component in
                HStack(spacing: 12) {
                    Image(systemName: component.systemImage)
                        .font(.title3)
                        .foregroundColor(component.tint)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(component.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(component.detail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var formPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Controls", subtitle: "Simple local state examples")

            VStack(spacing: 14) {
                Toggle("Enable collection sample", isOn: $isEnabled)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Sample rate")
                        Spacer()
                        Text("\(Int(sampleRate * 100))%")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $sampleRate, in: 0...1)
                    ProgressView(value: sampleRate)
                }

                Picker("Status", selection: $selectedStatus) {
                    ForEach(DemoStatus.allCases) { status in
                        Text(status.title).tag(status)
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Label(selectedStatus.title, systemImage: selectedStatus.systemImage)
                        .foregroundColor(selectedStatus.tint)
                    Spacer()
                    Button("Refresh") {
                        sampleRate = 0.75
                        isEnabled = true
                        selectedStatus = .normal
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct SectionTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

private struct SummaryCard: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(tint)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private enum DemoTab: String, CaseIterable, Identifiable {
    case overview
    case layout
    case controls

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .layout:
            return "Layout"
        case .controls:
            return "Controls"
        }
    }

    var subtitle: String {
        switch self {
        case .overview:
            return "Common SwiftUI display views"
        case .layout:
            return "Stack, grid, list-style composition"
        case .controls:
            return "Interactive controls backed by @State"
        }
    }
}

private enum DemoStatus: String, CaseIterable, Identifiable {
    case normal
    case warning
    case error

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .normal:
            return "Normal"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        }
    }

    var systemImage: String {
        switch self {
        case .normal:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .normal:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

private struct DemoComponent: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color

    static func components(for tab: DemoTab) -> [DemoComponent] {
        switch tab {
        case .overview:
            return [
                DemoComponent(title: "Text", detail: "Title, subtitle, caption, and secondary text styles", systemImage: "textformat", tint: .blue),
                DemoComponent(title: "Image", detail: "SF Symbols with font and foreground color", systemImage: "star.circle", tint: .orange),
                DemoComponent(title: "Label", detail: "Icon and text combined in one accessible view", systemImage: "tag", tint: .purple),
                DemoComponent(title: "ProgressView", detail: "Linear progress driven by local state", systemImage: "gauge.with.dots.needle.33percent", tint: .green)
            ]
        case .layout:
            return [
                DemoComponent(title: "VStack", detail: "Vertical content arrangement", systemImage: "rectangle.split.3x1", tint: .blue),
                DemoComponent(title: "HStack", detail: "Horizontal rows for icon, text, and actions", systemImage: "rectangle.split.1x2", tint: .purple),
                DemoComponent(title: "LazyVGrid", detail: "Adaptive two-column summary cards", systemImage: "square.grid.2x2", tint: .orange),
                DemoComponent(title: "ScrollView", detail: "Scrollable page for mixed component groups", systemImage: "arrow.up.and.down", tint: .green)
            ]
        case .controls:
            return [
                DemoComponent(title: "Toggle", detail: "Boolean state with a native switch", systemImage: "switch.2", tint: .green),
                DemoComponent(title: "Slider", detail: "Numeric value from 0 to 100 percent", systemImage: "slider.horizontal.3", tint: .orange),
                DemoComponent(title: "Picker", detail: "Menu and segmented picker styles", systemImage: "filemenu.and.selection", tint: .blue),
                DemoComponent(title: "Button", detail: "Reset action using bordered button style", systemImage: "button.programmable", tint: .purple)
            ]
        }
    }
}

struct SwiftUIDemoView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SwiftUIDemoView()
        }
    }
}
