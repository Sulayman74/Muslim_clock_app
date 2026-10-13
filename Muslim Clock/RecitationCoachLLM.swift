//
//  RecitationCoachLLM.swift
//  Muslim Clock — Correcteur de récitation (phase 7, optionnel)
//
//  Reformule les conseils (templates de `RecitationCoach`) en un court
//  paragraphe fluide avec le modèle de langue LOCAL d'Apple Intelligence.
//  Garde-fous :
//  - modèle `SystemLanguageModel.default` uniquement (sur l'appareil) — jamais
//    Private Cloud Compute, jamais de réseau ;
//  - le modèle ne reçoit que les conseils déjà calculés, ni audio ni texte
//    coranique à juger : il ne produit aucun contenu religieux ;
//  - indisponible (appareil non éligible, Apple Intelligence désactivée,
//    langue non prise en charge) → `nil`, l'UI garde les templates.
//

import Foundation
import FoundationModels
import os

enum RecitationCoachLLM {

    /// `true` si la reformulation locale est possible pour cette langue.
    static func isAvailable(languageCode: String) -> Bool {
        let model = SystemLanguageModel.default
        guard model.availability == .available else { return false }
        return model.supportsLocale(Locale(identifier: languageCode))
    }

    /// Paragraphe bienveillant (3 phrases max) à partir des conseils, ou `nil`.
    static func rephrase(tips: [CoachTip], languageCode: String) async -> String? {
        guard !tips.isEmpty, isAvailable(languageCode: languageCode) else { return nil }
        let instructions = """
        Tu es un professeur de récitation bienveillant. Reformule les remarques \
        fournies en un court paragraphe encourageant (3 phrases au maximum), en \
        tutoyant l'élève. N'ajoute AUCUNE information : pas de règle de tajwid, \
        pas de verset, pas de mot arabe qui ne figure pas dans les remarques, \
        pas de jugement religieux. Garde les numéros de versets tels quels. \
        Réponds dans la langue : \(languageCode).
        """
        let prompt = tips.map { "- \($0.textFr)" }.joined(separator: "\n")
        do {
            let session = LanguageModelSession(model: SystemLanguageModel.default, instructions: instructions)
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            Logger(subsystem: "com.kappsi.muslimclock", category: "Recitation")
                .error("Reformulation locale indisponible : \(error.localizedDescription)")
            return nil
        }
    }
}
