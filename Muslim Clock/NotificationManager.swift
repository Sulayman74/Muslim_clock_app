//
//  NotificationManager.swift
//  Muslim Clock
//

import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    // 1. Demande de permission (Inchangé)
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ [Notifs] Autorisation accordée !")
            } else if let error = error {
                print("❌ [Notifs] Erreur : \(error.localizedDescription)")
            }
        }
    }
    
    // 2. Programmer une liste de prières
    func schedulePrayerNotifications(prayers: [DailyPrayer], prayerDates: [Date]) {
        
        // On ne supprime PLUS les requêtes en attente !
        // À la place, on nettoie juste celles qui ont DÉJÀ sonné pour faire de la place sur le téléphone.
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        
        for (index, prayer) in prayers.enumerated() {
            let prayerDate = prayerDates[index]
            
            // Si l'heure est passée, on ignore
            if prayerDate < Date() { continue }
            let content = UNMutableNotificationContent()
            content.title = "C'est l'heure de la prière (\(prayer.time)) "
            content.body = "Il est l'heure de la prière de \(prayer.name)."
            content.sound = UNNotificationSound.default
            
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: prayerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            
            // 💡 L'ASTUCE EST ICI : On crée un ID unique pour CHAQUE jour et CHAQUE prière
            // Exemple généré : "prayer_Fajr_31_3_2026"
            let day = components.day ?? 0
            let month = components.month ?? 0
            let year = components.year ?? 0
            let uniqueID = "prayer_\(prayer.name)_\(day)_\(month)_\(year)"
            
            let request = UNNotificationRequest(identifier: uniqueID, content: content, trigger: trigger)
            
            // iOS va l'ajouter, ou la mettre à jour si elle existe déjà avec cet ID exact
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ [Notifs] Erreur pour \(prayer.name) : \(error.localizedDescription)")
                } else {
                    print("🔔 [Notifs] Programmée : \(prayer.name) à \(prayerDate.formatted(date: .omitted, time: .shortened))")
                }
            }
        }
    }
    
    // 3. NOUVELLE MÉTHODE : Pour programmer facilement juste le Fajr de demain
    func scheduleSinglePrayer(name: String, date: Date) {
        // On réutilise la logique principale en lui passant un tableau d'un seul élément
        let dummyPrayer = DailyPrayer(name: name, time: "", isNext: true)
        schedulePrayerNotifications(prayers: [dummyPrayer], prayerDates: [date])
    }
}
