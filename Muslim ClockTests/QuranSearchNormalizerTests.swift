//
//  QuranSearchNormalizerTests.swift
//  Muslim ClockTests
//
//  Tests de la normalisation arabe du Spotlight du Coran.
//

import Testing
@testable import Muslim_Clock

struct QuranSearchNormalizerTests {

    // MARK: - Harakât et signes

    @Test func stripsHarakat() {
        #expect(QuranSearchNormalizer.normalize("بِسْمِ اللَّهِ") == "بسم الله")
    }

    @Test func stripsSuperscriptAlefAndQuranicMarks() {
        // الرحمٰن (alef suscrit U+0670) + marque de waqf ۖ (U+06D6)
        #expect(QuranSearchNormalizer.normalize("الرَّحْمَٰنِ ۖ") == "الرحمن")
    }

    @Test func stripsOpenTanwinRemaps() {
        // Tanwin ouverts U+08F0–U+08F2 (remappés par le lecteur uthmani)
        #expect(QuranSearchNormalizer.normalize("قَدِير\u{08F1}") == "قدير")
    }

    // MARK: - Variantes de lettres

    @Test func unifiesAlefVariants() {
        #expect(QuranSearchNormalizer.normalize("ٱلْحَمْدُ") == "الحمد")
        #expect(QuranSearchNormalizer.normalize("أَنْعَمْتَ") == "انعمت")
        #expect(QuranSearchNormalizer.normalize("إِيَّاكَ") == "اياك")
        #expect(QuranSearchNormalizer.normalize("آمَنُوا") == "امنوا")
    }

    @Test func unifiesTaMarbutaAndAlefMaqsura() {
        #expect(QuranSearchNormalizer.normalize("الصَّلَاةَ") == "الصلاه")
        #expect(QuranSearchNormalizer.normalize("عَلَىٰ") == "علي")
    }

    @Test func unifiesHamzaCarriers() {
        #expect(QuranSearchNormalizer.normalize("يُؤْمِنُونَ") == "يومنون")
        #expect(QuranSearchNormalizer.normalize("بِئْسَ") == "بيس")
    }

    // MARK: - Séparateurs et robustesse

    @Test func nonArabicBecomesSeparator() {
        #expect(QuranSearchNormalizer.tokens("قل: هو 5 abc اللهُ") == ["قل", "هو", "الله"])
    }

    @Test func normalizeIsIdempotent() {
        let raw = "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ۝ ٱلْحَمْدُ"
        let once = QuranSearchNormalizer.normalize(raw)
        #expect(QuranSearchNormalizer.normalize(once) == once)
    }

    // MARK: - Basmala

    @Test func stripsLeadingBasmalaWhenFollowed() {
        let tokens = QuranSearchNormalizer.tokens("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ قُلْ هُوَ اللَّهُ أَحَدٌ")
        let stripped = QuranSearchNormalizer.strippingLeadingBasmala(tokens)
        #expect(stripped == ["قل", "هو", "الله", "احد"])
    }

    @Test func keepsBasmalaWhenAlone() {
        let tokens = QuranSearchNormalizer.tokens("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")
        #expect(QuranSearchNormalizer.strippingLeadingBasmala(tokens) == QuranSearchNormalizer.basmalaTokens)
    }
}
