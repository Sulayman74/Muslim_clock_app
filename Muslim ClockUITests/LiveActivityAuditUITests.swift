//
//  LiveActivityAuditUITests.swift
//  Muslim ClockUITests
//
//  Observation de la Live Activity « Prochaine Salât » (audit) : lance l'activité
//  de test du panneau DEBUG (cible = maintenant + 5 min), passe l'app en
//  arrière-plan et capture la Dynamic Island avant puis après l'heure cible.
//  À lancer sur un simulateur avec Dynamic Island (iPhone 17 Pro). Long (~6 min).
//

import XCTest

final class LiveActivityAuditUITests: XCTestCase {

    @MainActor
    func testDebugLiveActivityAcrossTargetTime() throws {
        let app = XCUIApplication()
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Autoriser", "Allow", "Autoriser lorsque l’app est active", "Allow While Using App"]
        where springboard.buttons[label].waitForExistence(timeout: 2) {
            springboard.buttons[label].tap()
        }

        let settings = app.tabBars.buttons["Réglages"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()

        let trigger = app.buttons["Tester Live Activity (5 min)"]
        for _ in 0..<25 where !trigger.isHittable { app.swipeUp() }
        XCTAssertTrue(trigger.isHittable, "bouton DEBUG introuvable")
        trigger.tap()
        sleep(2)

        XCUIDevice.shared.press(.home)
        sleep(3)
        snapshot(springboard, "LA-1-depart")

        // Dépasse l'heure cible (5 min) + quelques secondes, app en arrière-plan.
        sleep(5 * 60 + 30)
        snapshot(springboard, "LA-2-apres-heure-cible")
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
