//
//  SalatWidgetBundle.swift
//  SalatWidget
//
//  Created by Mohamed Kanoute on 31/03/2026.
//

import WidgetKit
import SwiftUI

@main
struct SalatWidgetBundle: WidgetBundle {
    var body: some Widget {
        SalatWidget()
        SalatWidgetControl()
        SalatWidgetLiveActivity()
    }
}
