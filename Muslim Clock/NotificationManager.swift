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
    
    // 2. Programmation par lot (Jusqu'à 14 jours)
    func scheduleBatchNotifications(names: [String], dates: [Date]) {
        let center = UNUserNotificationCenter.current()
        
        // On nettoie TOUT le calendrier précédent (évite les doublons si on a changé les réglages)
        center.removeAllPendingNotificationRequests()
        
        // On nettoie aussi les notifications restées affichées sur l'écran verrouillé
        center.removeAllDeliveredNotifications()
        
        // Limite stricte d'iOS : 64 notifications locales programmées. On sécurise à 60.
        let limit = min(names.count, 60)
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        for i in 0..<limit {
            let prayerName = names[i]
            let prayerDate = dates[i]
            let timeString = formatter.string(from: prayerDate)
            
            let content = UNMutableNotificationContent()
            // Titre dynamique (ex: "Fajr (05:44)")
            content.title = "\(prayerName) (\(timeString))"
            content.body = "C'est l'heure de la prière de \(prayerName)."
            content.sound = .default // Ou UNNotificationSound(named: UNNotificationSoundName("adhan.caf")) si tu mets un son
            
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: prayerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            
            // Un ID simple suffit, car on supprime tout au prochain recalcul
            let request = UNNotificationRequest(identifier: "prayer_\(i)", content: content, trigger: trigger)
            
            center.add(request)
        }
        
        print("🔔 [Notifs] \(limit) prières programmées avec succès pour les prochains jours !")
    }
}
