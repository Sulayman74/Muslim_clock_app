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
        SalatHomeWidget()         // Medium — ton widget original avec les sphères
        SalatSmallWidget()        // Small — carré compact prochaine prière
        SalatLockScreenWidget()   // Lock Screen — circular, rectangular, inline
    }
}
