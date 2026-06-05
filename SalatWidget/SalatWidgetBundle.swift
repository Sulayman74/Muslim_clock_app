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
        SalatProvider.SalatHomeWidget()         // Medium — ton widget original avec les sphères
        SalatProvider.SalatSmallWidget()        // Small — carré compact prochaine prière
        SalatProvider.SalatLockScreenWidget()   // Lock Screen — circular, rectangular, inline
        SalatProvider.SalatWatchCirclesWidget() // Apple Watch — 5 cercles (accessoryRectangular)
        SalatWidgetLiveActivity()               // Live Activity — Dynamic Island + Lock Screen countdown
        QiblaControlWidget()                    // Control Center — bouton Qibla (iOS 18+)
        AdhkarControlWidget()                   // Control Center — bouton Adhkar du moment (iOS 18+)
        QuranControlWidget()                    // Control Center — bouton Lire le Coran (iOS 18+)
    }
}
