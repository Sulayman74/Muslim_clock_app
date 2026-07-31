//
//  UpdateCheckMathTests.swift
//  Muslim ClockTests
//
//  Tests des décisions pures de mise à jour (UpdateCheckMath) :
//  comparaison de versions, throttle 24 h, bannière App Store, pop-up Quoi de neuf.
//

import Testing
@testable import Muslim_Clock

struct UpdateCheckMathTests {

    // MARK: - isNewer (comparaison numérique)

    @Test func isNewerBasicUpgrade() {
        #expect(UpdateCheckMath.isNewer(latest: "1.5.1", current: "1.5.0"))
        #expect(UpdateCheckMath.isNewer(latest: "2.0", current: "1.9.9"))
    }

    @Test func isNewerIsNumericNotLexicographic() {
        // "1.10" > "1.9" numériquement (l'ordre lexicographique dirait l'inverse).
        #expect(UpdateCheckMath.isNewer(latest: "1.10", current: "1.9"))
        #expect(!UpdateCheckMath.isNewer(latest: "1.9", current: "1.10"))
    }

    @Test func isNewerFalseWhenSameOrOlder() {
        #expect(!UpdateCheckMath.isNewer(latest: "1.5.0", current: "1.5.0"))
        #expect(!UpdateCheckMath.isNewer(latest: "1.4.0", current: "1.5.0"))
    }

    // MARK: - isCheckDue (throttle 24 h)

    @Test func checkDueWhenNeverChecked() {
        #expect(UpdateCheckMath.isCheckDue(lastCheck: 0, now: 1_000_000))
    }

    @Test func checkThrottledWithin24Hours() {
        let last: Double = 1_000_000
        #expect(!UpdateCheckMath.isCheckDue(lastCheck: last, now: last + 86_399))
    }

    @Test func checkDueAfter24Hours() {
        let last: Double = 1_000_000
        #expect(UpdateCheckMath.isCheckDue(lastCheck: last, now: last + 86_400))
    }

    @Test func checkDueWhenClockRolledBack() {
        // Horloge reculée : date de dernier check dans le futur → re-check.
        let last: Double = 1_000_000
        #expect(UpdateCheckMath.isCheckDue(lastCheck: last, now: last - 60))
    }

    // MARK: - shouldShowBanner

    @Test func bannerShownForNewerUndismissedVersion() {
        #expect(UpdateCheckMath.shouldShowBanner(latest: "1.6.0", current: "1.5.0", dismissed: nil))
        #expect(UpdateCheckMath.shouldShowBanner(latest: "1.6.0", current: "1.5.0", dismissed: "1.5.5"))
    }

    @Test func bannerHiddenWhenVersionDismissed() {
        #expect(!UpdateCheckMath.shouldShowBanner(latest: "1.6.0", current: "1.5.0", dismissed: "1.6.0"))
    }

    @Test func bannerHiddenWhenUpToDate() {
        #expect(!UpdateCheckMath.shouldShowBanner(latest: "1.5.0", current: "1.5.0", dismissed: nil))
        #expect(!UpdateCheckMath.shouldShowBanner(latest: "1.4.0", current: "1.5.0", dismissed: nil))
    }

    // MARK: - whatsNewAction

    @Test func whatsNewShownOnRealUpgrade() {
        #expect(UpdateCheckMath.whatsNewAction(current: "1.6.0", lastSeen: "1.5.0") == .show)
        // Saut de plusieurs versions → toujours une seule sheet.
        #expect(UpdateCheckMath.whatsNewAction(current: "2.0", lastSeen: "1.4.0") == .show)
    }

    @Test func whatsNewRecordsSilentlyOnFirstInstall() {
        #expect(UpdateCheckMath.whatsNewAction(current: "1.6.0", lastSeen: "") == .recordOnly)
    }

    @Test func whatsNewRecordsSilentlyOnDowngrade() {
        // Downgrade TestFlight → resync sans sheet.
        #expect(UpdateCheckMath.whatsNewAction(current: "1.5.0", lastSeen: "1.6.0") == .recordOnly)
    }

    @Test func whatsNewNothingWhenSameVersionOrUnreadable() {
        #expect(UpdateCheckMath.whatsNewAction(current: "1.5.0", lastSeen: "1.5.0") == .nothing)
        // Info.plist illisible → ne rien faire (surtout pas d'écriture).
        #expect(UpdateCheckMath.whatsNewAction(current: "", lastSeen: "1.5.0") == .nothing)
    }
}
