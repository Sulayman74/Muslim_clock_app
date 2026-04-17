import SwiftUI
import CoreLocation

struct WeatherMiniWidget: View {
    @EnvironmentObject var weatherVM: WeatherViewModel
    var location: CLLocation?
    var cityName: String // On reçoit la ville du CompassManager !
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: weatherVM.conditionIcon)
                .font(.system(size: 30))
                .symbolVariant(.fill)
                .symbolRenderingMode(.multicolor)
            Text(verbatim: weatherVM.temperature)
                .font(.system(.title3, design: .rounded).bold())
                .foregroundColor(.white)
            Text(verbatim: cityName)
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
    }
}

struct NextPrayerWidget: View {
    // 1. 🔌 On attrape le cerveau global injecté par MainView
        @EnvironmentObject var prayerVM: PrayerTimesViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            Text(verbatim: prayerVM.nextPrayerName)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(verbatim: prayerVM.nextPrayerTime)
                .font(.system(size: 24, weight: .light, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
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
    @AppStorage("iqamahFajrDelay")    private var iqamahFajr    = 10
    @AppStorage("iqamahDhuhrDelay")   private var iqamahDhuhr   = 10
    @AppStorage("iqamahAsrDelay")     private var iqamahAsr     = 10
    @AppStorage("iqamahMaghribDelay") private var iqamahMaghrib = 5
    @AppStorage("iqamahIshaDelay")    private var iqamahIsha    = 10
    
    private func iqamahDelay(for name: String) -> Int {
        switch name {
        case "Fajr":            return iqamahFajr
        case "Dhuhr", "Jumu'ah": return iqamahDhuhr
        case "Asr":             return iqamahAsr
        case "Maghrib":         return iqamahMaghrib
        case "Isha":            return iqamahIsha
        default:                return 0
        }
    }
    
    private func iqamahTime(for prayer: DailyPrayer) -> String? {
        let delay = iqamahDelay(for: prayer.name)
        guard delay > 0 else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: prayer.date.addingTimeInterval(Double(delay) * 60))
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(prayerVM.dailyPrayers) { prayer in
                HStack(spacing: 12) {
                    // Nom de la prière
                    Text(verbatim: prayer.name)
                        .font(.headline)
                        .foregroundStyle(prayer.isNext ? .green : .primary)
                    
                    // Badge "En cours" (Priorité sur prochaine)
                    if prayer.isCurrent {
                        Text("En cours")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.orange.gradient)
                            .clipShape(Capsule())
                    } else if prayer.isNext {
                        Text("Prochaine")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.green.gradient)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    // Horaire adhan + iqamah
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(verbatim: prayer.time)
                            .font(.system(.title3, design: .rounded).bold())
                            .foregroundStyle(prayer.isNext ? .green : (prayer.isCurrent ? .orange : .primary))
                        
                        if let iqamah = iqamahTime(for: prayer) {
                            HStack(spacing: 3) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(.indigo.opacity(0.6))
                                
                                Text(verbatim: iqamah)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                        }
                    } // fin VStack horaires
                } // fin HStack de la ligne
                .padding(.horizontal, 20)
                .frame(height: 70)
                // ✅ Liquid Glass pour la prochaine, material classique pour les autres
                .background {
                                    if prayer.isNext || prayer.isCurrent {
                                        Color.clear
                                    } else {
                                        RoundedRectangle(cornerRadius: 20).fill(.regularMaterial)
                                    }
                                }
                                .if(prayer.isNext) { view in
                                    view.glassEffect(.regular.tint(.green.opacity(0.15)), in: RoundedRectangle(cornerRadius: 20))
                                }
                                .if(prayer.isCurrent) { view in
                                    view.glassEffect(.regular.tint(.orange.opacity(0.15)), in: RoundedRectangle(cornerRadius: 20))
                                }
                                .if(!prayer.isNext && !prayer.isCurrent) { view in
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
