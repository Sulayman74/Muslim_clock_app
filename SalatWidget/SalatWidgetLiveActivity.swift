//
//  SalatWidgetLiveActivity.swift
//  SalatWidget
//
//  Created by Mohamed Kanoute on 31/03/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct SalatWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct SalatWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SalatWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension SalatWidgetAttributes {
    fileprivate static var preview: SalatWidgetAttributes {
        SalatWidgetAttributes(name: "World")
    }
}

extension SalatWidgetAttributes.ContentState {
    fileprivate static var smiley: SalatWidgetAttributes.ContentState {
        SalatWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: SalatWidgetAttributes.ContentState {
         SalatWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: SalatWidgetAttributes.preview) {
   SalatWidgetLiveActivity()
} contentStates: {
    SalatWidgetAttributes.ContentState.smiley
    SalatWidgetAttributes.ContentState.starEyes
}
