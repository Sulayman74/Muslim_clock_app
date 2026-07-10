//
//  String+Search.swift
//  Muslim Clock — helpers de normalisation pour la recherche.
//

import Foundation

extension String {
    /// Minuscules + suppression des accents FR (« priere » trouve « prière »).
    var searchFoldedFr: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr"))
    }

    /// Retire harakât, tanwîn, shadda, sukûn, madda, tatwîl — permet de chercher
    /// « الحمد لله » dans un texte entièrement vocalisé.
    var strippedTashkeel: String {
        let marks = CharacterSet(charactersIn: "\u{064B}\u{064C}\u{064D}\u{064E}\u{064F}\u{0650}\u{0651}\u{0652}\u{0653}\u{0670}\u{0640}")
        return String(unicodeScalars.filter { !marks.contains($0) })
    }
}
