//
//  DonationManager.swift
//  Muslim Clock — module Contribution
//
//  Gestion des achats consumables (« tip jar ») via StoreKit 2.
//  Aucun backend — Apple gère paiement, taxes, devises, remboursements.
//

import Foundation
import StoreKit

/// Identifiants techniques des produits IAP. **Doivent matcher** ceux créés
/// dans App Store Connect — la moindre divergence empêche le chargement.
enum DonationProductID {
    static let small  = "clock.tip.small"     // ~1,99 €
    static let medium = "clock.tip.medium"    // ~4,99 €
    static let large  = "clock.tip.large"     // ~9,99 €
    static let xlarge = "clock.tip.xlarge"    // ~19,99 €

    static let all: [String] = [small, medium, large, xlarge]

    /// Emoji affiché à côté du nom dans la sheet. Évite de devoir
    /// le mettre dans le `displayName` côté App Store Connect — plus de
    /// contrôle visuel côté app + pas de risque review sur les emojis.
    static func emoji(for productID: String) -> String {
        switch productID {
        case small:  return "🤍"
        case medium: return "☕"
        case large:  return "🌙"
        case xlarge: return "✨"
        default:     return ""
        }
    }
}

/// État du flow d'achat. Pilote l'UI de DonationView (placeholder, overlay
/// de remerciement, message d'erreur, etc.).
enum DonationPurchaseState: Equatable {
    case idle
    case purchasing
    case success
    case pending           // Ask to Buy (contrôle parental)
    case failed(String)
}

@MainActor
@Observable
final class DonationManager {

    /// Produits chargés depuis l'App Store, triés par prix croissant.
    private(set) var products: [Product] = []

    /// État du dernier achat tenté.
    private(set) var purchaseState: DonationPurchaseState = .idle

    /// Indique si le chargement initial des produits est en cours.
    private(set) var isLoading: Bool = false

    /// Charge les produits depuis l'App Store. Idempotent : ne refait rien si
    /// la liste est déjà non vide ou si un load est en cours.
    func loadProducts() async {
        guard products.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: DonationProductID.all)
            self.products = loaded.sorted { $0.price < $1.price }
        } catch {
            // Log discret — le UI gère l'état vide.
            print("⚠️ [Donation] Échec du chargement des produits : \(error)")
        }
    }

    /// Lance l'achat d'un produit consumable. Pas de restore — un consumable
    /// est par définition usé immédiatement (et le pattern « tip jar » suppose
    /// un soutien répétable, pas une fonctionnalité débloquée).
    func purchase(_ product: Product) async {
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    purchaseState = .failed(String(localized: "Vérification de l'achat échouée"))
                    return
                }
                // `finish()` indispensable pour un consumable — sinon la
                // transaction reste pending et bloque les futurs achats.
                await transaction.finish()
                purchaseState = .success

            case .userCancelled:
                purchaseState = .idle

            case .pending:
                purchaseState = .pending

            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    /// Remet l'état à idle (utile après affichage du remerciement).
    func resetState() {
        purchaseState = .idle
    }
}
