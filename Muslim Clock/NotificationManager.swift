//
//  NotificationManager.swift
//  Muslim Clock
//

import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    // 1. Demande de permission (Appelé au lancement de l'app)
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ [Notifs] Autorisation accordée !")
            } else if let error = error {
                print("❌ [Notifs] Erreur : \(error.localizedDescription)")
            }
        }
    }
    
    // 2. Programmation par lot (prières 14 jours + nouvelles lunes 6 mois)
    // Total max : 56 prières + 6 nouvelles lunes = 62 < limite iOS de 64
    func scheduleBatchNotifications(names: [String], dates: [Date]) {
        let center = UNUserNotificationCenter.current()
        
        // Table rase : évite tout conflit d'IDs ou dépassement de limite
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        
        // 56 slots max pour les prières (8 slots réservés aux nouvelles lunes)
        let limit = min(names.count, 56)
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        for i in 0..<limit {
            let prayerName = names[i]
            let prayerDate = dates[i]
            
            let content = UNMutableNotificationContent()
            content.title = "\(prayerName) (\(formatter.string(from: prayerDate)))"
            content.body  = "C'est l'heure de la prière du \(prayerName)."
            content.sound = .default
            content.userInfo = [
                "prayerName": prayerName,
                "prayerTime": prayerDate.timeIntervalSince1970
            ]
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: prayerDate)
            let trigger    = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request    = UNNotificationRequest(identifier: "prayer_\(i)", content: content, trigger: trigger)
            center.add(request)
        }
        
        print("🔔 [Notifs] \(limit) prières programmées pour les prochains jours")
        
        // Nouvelles lunes ajoutées en fin de batch (slots 57-62)
        scheduleNewMoonNotifications()
    }
    
    // 3. Nouvelles lunes — appelé automatiquement depuis scheduleBatchNotifications
    func scheduleNewMoonNotifications(months: Int = 6) {
        let center = UNUserNotificationCenter.current()
        let hijri  = Calendar(identifier: .islamicUmmAlQura)
        let greg   = Calendar.current
        let now    = Date()
        
        var comps = hijri.dateComponents([.year, .month, .day], from: now)
        
        for _ in 0..<months {
            // Avancer au 1er du mois hégirien suivant
            var m = (comps.month ?? 1) + 1
            var y = comps.year ?? 1446
            if m > 12 { m = 1; y += 1 }
            comps.month = m
            comps.year  = y
            comps.day   = 1
            
            guard let newMoonDate = hijri.date(from: comps) else { continue }
            
            // Notification à 20h00 heure locale
            var notifComps      = greg.dateComponents([.year, .month, .day], from: newMoonDate)
            notifComps.hour     = 20
            notifComps.minute   = 0
            
            let content      = UNMutableNotificationContent()
            content.title    = "🌙 Nouvelle Lune — Hilal"
            content.body     = "اللَّهُمَّ أَهِلَّهُ عَلَيْنَا بِالأَمْنِ وَالإِيمَانِ وَالسَّلَامَةِ وَالإِسْلَامِ"
            content.sound    = .default
            
            let trigger  = UNCalendarNotificationTrigger(dateMatching: notifComps, repeats: false)
            let id       = "newmoon_\(y)-\(m)"
            let request  = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            
            center.add(request) { error in
                if let error = error {
                    print("❌ [Notifs] Nouvelle lune \(id) : \(error)")
                }
            }
        }
        print("🌙 [Notifs] \(months) nouvelles lunes programmées")
    }

    // 4. 🧪 Fonction de test pour planifier une seule notification Adhan
    func scheduleAdhan(for prayerName: String, at date: Date) {
        let center = UNUserNotificationCenter.current()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeString = formatter.string(from: date)
        
        let content = UNMutableNotificationContent()
        content.title = "🕌 \(prayerName) (\(timeString))"
        content.body = "C'est l'heure de la prière du \(prayerName)."
        content.sound = .default
        content.userInfo = ["prayerName": prayerName, "prayerTime": date.timeIntervalSince1970]
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: "test_adhan", content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("❌ Erreur lors de la planification du test Adhan : \(error)")
            } else {
                print("✅ Test Adhan planifié pour \(timeString)")
            }
        }
    }
}
