//
//  WidgetDemo.swift
//  WidgetDemo
//
//  Created by hulilei on 2022/9/23.
//  Copyright © 2022 DataFlux-cn. All rights reserved.
//

import WidgetKit
import SwiftUI
import FTMobileExtension

class WidgetEntryViewModel: ObservableObject {
    static let shared = WidgetEntryViewModel() 
    private var hasReportedView = false
    
    func reportViewIfNeeded(viewName: String) {
        guard !hasReportedView else { return }
        FTExternalDataManager.shared().startView(withName: viewName)
        hasReportedView = true
    }
}
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []
        let httpEngine = HttpEngine()
        httpEngine.network { data, response, error in
            
        };
        FTExtensionManager.sharedInstance().logging("getTimeline", status: .statusInfo)
        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct WidgetDemoEntryView : View {
    var entry: Provider.Entry
    @StateObject private var viewModel = WidgetEntryViewModel.shared
    
    init(entry: Provider.Entry) {
        self.entry = entry
        FTExternalDataManager.shared().startView(withName: "WidgetDemoEntryView")
    }
    var body: some View {
        Text(entry.date, style: .time)
            .onAppear {
                           viewModel.reportViewIfNeeded(viewName: "WidgetDemoEntryView")
                       }
    }
}

@main
struct WidgetDemo: Widget {
    let kind: String = "WidgetDemo"
    init() {
        let extensionConfig = FTExtensionConfig.init(groupIdentifier: "group.com.ft.widget.demo")
        extensionConfig.enableTrackAppCrash = true
        extensionConfig.enableRUMAutoTraceResource = true
        extensionConfig.enableTracerAutoTrace = true
        extensionConfig.enableSDKDebugLog = true
        FTExtensionManager.start(with: extensionConfig)
    }
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetDemoEntryView(entry: entry)
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
    }
}

struct WidgetDemo_Previews: PreviewProvider {
    static var previews: some View {
        WidgetDemoEntryView(entry: SimpleEntry(date: Date()))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
