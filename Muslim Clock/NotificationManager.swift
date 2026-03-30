//
//  NotificationManager.swift
//  Muslim Clock
//
//  Created by Mohamed Kanoute on 30/03/2026.
//

import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager() // Un Singleton pour y accéder partout
    
    // 1. Demander la permission à l'utilisateur (La petite popup d'Apple)
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ [Notifs] Autorisation accordée !")
            } else if let error = error {
                print("❌ [Notifs] Erreur : \(error.localizedDescription)")
            }
        }
    }
    
    // 2. Programmer les notifications pour les 5 prières
    func schedulePrayerNotifications(prayers: [DailyPrayer], prayerDates: [Date]) {
        // On annule les anciennes notifications pour ne pas faire de doublons
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        for (index, prayer) in prayers.enumerated() {
            let prayerDate = prayerDates[index]
            
            // Si l'heure de la prière est déjà passée aujourd'hui, on ne la programme pas !
            if prayerDate < Date() { continue }
            
            let content = UNMutableNotificationContent()
            content.title = "C'est l'heure de la prière"
            content.body = "Il est l'heure de la prière de \(prayer.name)."
            // Pour l'instant on met le son par défaut d'Apple (On pourra mettre un vrai Adhan plus tard !)
            content.sound = UNNotificationSound.default
            
            // On extrait l'heure et les minutes exactes de la prière
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: prayerDate)
            
            // On crée le "déclencheur" basé sur l'heure
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            
            // On crée la requête et on l'envoie à iOS
            let request = UNNotificationRequest(identifier: "prayer_\(prayer.name)", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ [Notifs] Erreur pour \(prayer.name) : \(error.localizedDescription)")
                } 
            }
        }
    }
}
