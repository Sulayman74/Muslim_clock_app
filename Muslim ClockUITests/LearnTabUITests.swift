//
//  LearnTabUITests.swift
//  Muslim ClockUITests
//
//  Parcours de fumée de l'onglet Apprendre : hub → révision de la semaine →
//  réponse → explication → résultat, puis thèmes. Capture chaque écran
//  (pièces jointes du .xcresult) pour la revue visuelle.
//

import XCTest

final class LearnTabUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testWeeklyReviewFlow() throws {
        let app = XCUIApplication()
        app.launch()
        dismissInterruptions(app)

        let learnTab = app.tabBars.buttons["Apprendre"]
        XCTAssertTrue(learnTab.waitForExistence(timeout: 10))
        learnTab.tap()
        dismissInterruptions(app)
        snapshot(app, "1-hub")

        let start = app.buttons["Commencer"].exists ? app.buttons["Commencer"] : app.buttons["Refaire"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        let next = app.buttons["quiz.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        snapshot(app, "2-question")

        // Répond à chaque question (2e choix), jusqu'à l'écran de résultat.
        let close = app.buttons["quiz.result.close"]
        for index in 0..<30 where !close.exists {
            let choice = app.buttons["quiz.choice.1"]
            XCTAssertTrue(choice.waitForExistence(timeout: 5))
            choice.tap()
            if index == 0 { snapshot(app, "3-explication") }
            XCTAssertTrue(next.isEnabled)
            next.tap()
        }
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        snapshot(app, "4-resultat")
        close.tap()

        let topics = app.buttons["Par thème"]
        XCTAssertTrue(topics.waitForExistence(timeout: 5))
        topics.tap()
        sleep(1)
        snapshot(app, "5-themes")
    }

    // MARK: - Helpers

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        sleep(1)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Ferme les alertes système (localisation, notifications) et les feuilles
    /// d'accueil (Quoi de neuf, popup saisonnier) qui masqueraient l'onglet.
    @MainActor
    private func dismissInterruptions(_ app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowLabels = ["Autoriser", "Allow", "Autoriser lorsque l’app est active", "Allow While Using App", "Autoriser une fois", "Allow Once"]
        for _ in 0..<4 {
            var tapped = false
            for label in allowLabels where springboard.buttons[label].waitForExistence(timeout: 1) {
                springboard.buttons[label].tap()
                tapped = true
                break
            }
            if !tapped { break }
        }
        for label in ["Continuer", "Continue", "C'est parti", "Plus tard", "Ignorer", "Fermer"] {
            let button = app.buttons[label]
            if button.waitForExistence(timeout: 1), !app.tabBars.buttons["Apprendre"].isHittable {
                button.tap()
            }
        }
        if !app.tabBars.buttons["Apprendre"].isHittable {
            app.swipeDown(velocity: .fast)
        }
    }
}
