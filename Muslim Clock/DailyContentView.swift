import SwiftUI
import Combine

struct DailyContentView: View {
    @StateObject private var service = DailyContentService()
    
    // État local pour basculer arabe/français sur chaque carte
    @State private var showAyahArabic = false
    @State private var showHadithArabic = false
    
    var body: some View {
        VStack(spacing: 20) {
            
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // CARTE CORAN
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "book.fill")
                    Text("Verset du Jour")
                        .font(.caption.bold())
                    
                    Spacer()
                    
                    // Bouton bascule Arabe/Français
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showAyahArabic.toggle()
                        }
                    } label: {
                        Text(showAyahArabic ? "FR" : "عربي")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    
                    ShareLink(item: "\(service.dailyAyah)\n\n\(service.dailyAyahArabic)\n\n— \(service.dailyAyahSource)") {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.indigo)
                
                // Contenu avec transition
                if showAyahArabic {
                    Text(service.dailyAyahArabic)
                        .font(.system(size: 22, weight: .regular))
                        .multilineTextAlignment(.trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .lineSpacing(10)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    Text(service.dailyAyah)
                        .font(.system(.body, design: .serif))
                        .italic()
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentTransition(.opacity)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
                
                Text("— \(service.dailyAyahSource)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.opacity)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .cornerRadius(25)
            .clipped()
            
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // CARTE HADITH
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "quote.opening")
                    Text("Hadith du Jour")
                        .font(.caption.bold())
                    
                    Spacer()
                    
                    // Bouton bascule Arabe/Français
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showHadithArabic.toggle()
                        }
                    } label: {
                        Text(showHadithArabic ? "FR" : "عربي")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    
                    ShareLink(item: "\(service.dailyHadith)\n\n\(service.dailyHadithArabic)\n\n— \(service.dailyHadithSource)") {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.teal)
                
                // Contenu avec transition
                if showHadithArabic {
                    Text(service.dailyHadithArabic)
                        .font(.system(size: 22, weight: .regular))
                        .multilineTextAlignment(.trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .lineSpacing(10)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    Text(service.dailyHadith)
                        .font(.system(.body, design: .serif))
                        .italic()
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentTransition(.opacity)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
                
                Text("— \(service.dailyHadithSource)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.opacity)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .cornerRadius(25)
            .clipped()
        }
        .redacted(reason: service.isLoading ? .placeholder : [])
        .animation(.easeInOut(duration: 0.2), value: service.isLoading)
        .task {
            await service.fetchDailyContent()
        }
    }
}
