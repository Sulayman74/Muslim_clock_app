//
//  DonationView.swift
//  Muslim Clock — module Contribution
//
//  Sheet présentée depuis SettingsView. Affiche les 4 tiers chargés via
//  StoreKit 2, déclenche le flow d'achat natif Apple, puis affiche un
//  overlay de remerciement avant dismiss.
//

import SwiftUI
import StoreKit

struct DonationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var manager = DonationManager()
    @State private var showThankYou = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.06, blue: 0.18),
                        Color(red: 0.02, green: 0.02, blue: 0.08)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                if showThankYou {
                    thankYouOverlay
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                } else {
                    mainContent
                }
            }
            .navigationTitle("Offrir une contribution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .task { await manager.loadProducts() }
            .onChange(of: manager.purchaseState) { _, new in
                guard new == .success else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showThankYou = true
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2.6))
                    manager.resetState()
                    dismiss()
                }
            }
        }
        .preferredColorScheme(.dark)
        // Haptic léger au succès d'un achat.
        .sensoryFeedback(.success, trigger: showThankYou)
    }

    // MARK: - Main content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                if manager.isLoading {
                    ProgressView()
                        .tint(.teal)
                        .padding(40)
                } else if manager.products.isEmpty {
                    Text("Les contributions ne sont pas disponibles pour le moment. Réessaie plus tard.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 40)
                } else {
                    productList
                }

                if case .failed(let msg) = manager.purchaseState {
                    errorBanner(message: msg)
                }

                disclaimer
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 50))
                .foregroundStyle(.teal)
                .symbolEffect(.pulse)

            Text("Muslim Clock est développé en indépendant, sans publicité ni tracker.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)

            Text("Si l'app t'aide au quotidien, tu peux participer à son développement avec une contribution symbolique.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var productList: some View {
        VStack(spacing: 12) {
            ForEach(manager.products, id: \.id) { product in
                productRow(product: product)
            }
        }
    }

    private func productRow(product: Product) -> some View {
        Button {
            Task { await manager.purchase(product) }
        } label: {
            HStack(spacing: 14) {
                Text(verbatim: DonationProductID.emoji(for: product.id))
                    .font(.system(size: 28))
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(product.displayName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if !product.description.isEmpty {
                        Text(product.description)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.teal)
                    .monospacedDigit()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.teal.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(manager.purchaseState == .purchasing)
        .opacity(manager.purchaseState == .purchasing ? 0.5 : 1.0)
    }

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(verbatim: message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(3)
        }
        .padding(12)
        .background(Color.orange.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var disclaimer: some View {
        Text("Cette contribution n'est pas un don au sens fiscal — c'est un soutien direct au développement, traité par Apple via l'App Store. Aucun reçu fiscal ne peut être délivré.")
            .font(.caption2)
            .foregroundColor(.white.opacity(0.5))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.top, 8)
    }

    // MARK: - Thank you overlay

    private var thankYouOverlay: some View {
        VStack(spacing: 18) {
            Image(systemName: "heart.fill")
                .font(.system(size: 70))
                .foregroundStyle(.pink.gradient)
                .symbolEffect(.bounce, value: showThankYou)

            Text(verbatim: "جزاك الله خيرا")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)

            Text("Qu'Allah te récompense pour ton soutien.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .padding(40)
        .glassEffect(.regular.tint(.pink.opacity(0.15)), in: RoundedRectangle(cornerRadius: 30))
        .shadow(color: .pink.opacity(0.3), radius: 20)
    }
}
