//
//  IqamahDefaultsTests.swift
//  Muslim ClockTests
//
//  Source unique des délais iqamah : clés et valeurs par défaut.
//

import Testing
@testable import Muslim_Clock

struct IqamahDefaultsTests {

    @Test func delaysDictionaryCoversTheFiveDailyPrayers() {
        let d = IqamahDefaults.delays(
            fajr: IqamahDefaults.fajr, dhuhr: IqamahDefaults.dhuhr, asr: IqamahDefaults.asr,
            maghrib: IqamahDefaults.maghrib, isha: IqamahDefaults.isha
        )
        #expect(d.count == 5)
        #expect(d["Fajr"] == 20)
        #expect(d["Dhuhr"] == 15)
        #expect(d["Asr"] == 15)
        #expect(d["Maghrib"] == 5)
        #expect(d["Isha"] == 15)
        // Jumu'ah n'a pas d'iqamah : l'heure est saisie directement par l'utilisateur.
        #expect(d["Jumu'ah"] == nil)
    }

    @Test func keysAreTheHistoricalUserDefaultsKeys() {
        // Changer une valeur de clé serait une migration : les réglages existants seraient perdus.
        #expect(StorageKeys.iqamahFajrDelay == "iqamahFajrDelay")
        #expect(StorageKeys.iqamahDhuhrDelay == "iqamahDhuhrDelay")
        #expect(StorageKeys.iqamahAsrDelay == "iqamahAsrDelay")
        #expect(StorageKeys.iqamahMaghribDelay == "iqamahMaghribDelay")
        #expect(StorageKeys.iqamahIshaDelay == "iqamahIshaDelay")
    }
}
