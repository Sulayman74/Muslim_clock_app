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
                .symbolRenderingMode(.multicolor)
            Text(weatherVM.temperature)
                .font(.system(.title3, design: .rounded).bold())
            Text(cityName) // Affichage direct !
                .font(.caption2)
                .opacity(0.8)
                .lineLimit(1)
        }
        .frame(width: 100, height: 100)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
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
    @ObservedObject var prayerVM: PrayerTimesViewModel // OBSERVE LE CERVEAU
    var location: CLLocation?
    
    var body: some View {
        VStack(spacing: 8) {
            Text(prayerVM.nextPrayerName)
                .font(.caption.bold())
                .foregroundColor(.indigo)
            Text(prayerVM.nextPrayerTime)
                .font(.system(.title3, design: .rounded).bold())
            
            if let targetDate = prayerVM.nextPrayerDate {
                Text(timerInterval: Date()...targetDate, countsDown: true)
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
            } else {
                Text("Terminé").font(.caption2).foregroundColor(.secondary)
            }
        }
        .frame(width: 100, height: 100)
        .background(.regularMaterial)
        .cornerRadius(20)
        .redacted(reason: prayerVM.isLoading ? .placeholder : []) // SKELETON RESTAURÉ
        .animation(.easeInOut(duration: 0.3), value: prayerVM.isLoading)
        .onChange(of: location) { oldLocation, newLocation in
            if let loc = newLocation { prayerVM.calculatePrayers(for: loc) }
        }
    }
}

struct PrayerListView: View {
    @ObservedObject var prayerVM: PrayerTimesViewModel // OBSERVE LE CERVEAU
    var location: CLLocation?
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(prayerVM.dailyPrayers) { prayer in
                HStack {
                    Text(prayer.name).font(.headline).foregroundColor(prayer.isNext ? .green : .primary)
                    Spacer()
                    Text(prayer.time).font(.system(.title3, design: .rounded).bold()).foregroundColor(prayer.isNext ? .green : .primary)
                }
                .padding(.horizontal, 20)
                .frame(height: 70)
                .background(.regularMaterial)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20).stroke(prayer.isNext ? Color.green.opacity(0.8) : Color.clear, lineWidth: 2)
                )
            }
        }
        .redacted(reason: prayerVM.isLoading ? .placeholder : []) // SKELETON RESTAURÉ
        .animation(.easeInOut(duration: 0.3), value: prayerVM.isLoading)
        .onChange(of: location) { oldLocation, newLocation in
            if let loc = newLocation { prayerVM.calculatePrayers(for: loc) }
        }
    }
}
