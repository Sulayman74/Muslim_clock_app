import SwiftUI
import CoreLocation

struct WeatherMiniWidget: View {
    @StateObject private var weatherVM = WeatherViewModel()
    var location: CLLocation?
    var cityName: String // On reçoit la ville du CompassManager !
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: weatherVM.conditionIcon)
                .font(.system(size: 30))
                .symbolVariant(.fill)
                .symbolRenderingMode(.multicolor)
            Text(weatherVM.temperature)
                .font(.system(.title3, design: .rounded).bold())
                .foregroundColor(.white)
            Text(cityName) // Affichage direct !
                .font(.caption2)
                .opacity(0.8)
                .foregroundColor(.indigo)
                .lineLimit(1)
        }
        .frame(width: 100, height: 100)
        .padding(10)
        .glassEffect(.regular, in: .circle)
        .redacted(reason: weatherVM.isLoading ? .placeholder : []) // SKELETON RESTAURÉ
        .animation(.easeInOut(duration: 0.3), value: weatherVM.isLoading)
        .onChange(of: location) { oldLocation, newLocation in
            if let loc = newLocation {
                Task { await weatherVM.fetchWeather(for: loc) }
            }
        }
    }
}

struct NextPrayerWidget: View {
    // 1. 🔌 On attrape le cerveau global injecté par MainView
        @EnvironmentObject var prayerVM: PrayerTimesViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            Text(prayerVM.nextPrayerName)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(prayerVM.nextPrayerTime)
                .font(.system(size: 22, weight: .light, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
            
            if let targetDate = prayerVM.nextPrayerDate {
                Text(timerInterval: Date()...targetDate, countsDown: true)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            } else {
                Text("Terminé").font(.caption2).foregroundColor(.secondary)
            }
        }
        .frame(width: 100, height: 100)
        .padding(10)
        .glassEffect(.clear, in: .circle)
        .redacted(reason: prayerVM.isLoading ? .placeholder : []) // SKELETON RESTAURÉ
        .animation(.easeInOut(duration: 0.3), value: prayerVM.isLoading)
    }
}

struct PrayerListView: View {
    @EnvironmentObject var prayerVM: PrayerTimesViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(prayerVM.dailyPrayers) { prayer in
                HStack(spacing: 12) {
                    // Nom de la prière
                    Text(prayer.name)
                        .font(.headline)
                        .foregroundStyle(prayer.isNext ? .green : .primary)
                    
                    // ✅ Badge "Prochaine" si c'est la next
                    if prayer.isNext {
                        Text("Prochaine")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.green.gradient)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    // Horaire
                    Text(prayer.time)
                        .font(.system(.title3, design: .rounded).bold())
                        .foregroundStyle(prayer.isNext ? .green : .primary)
                }
                .padding(.horizontal, 20)
                .frame(height: 70)
                // ✅ Liquid Glass pour la prochaine, material classique pour les autres
                .background {
                    if prayer.isNext {
                        // Pas de fond opaque — le glassEffect gère tout
                        Color.clear
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.regularMaterial)
                    }
                }
                .if(prayer.isNext) { view in
                    view.glassEffect(.regular.tint(.green.opacity(0.15)), in: RoundedRectangle(cornerRadius: 20))
                }
                .if(!prayer.isNext) { view in
                    view.cornerRadius(20)
                }
            }
        }
        .redacted(reason: prayerVM.isLoading ? .placeholder : [])
        .animation(.easeInOut(duration: 0.3), value: prayerVM.isLoading)
    }
}
 
// MARK: - Conditional View Modifier
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
