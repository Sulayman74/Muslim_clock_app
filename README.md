# 🕌 Muslim Clock

![Swift](https://img.shields.io/badge/Swift-5.9-FA7343?style=for-the-badge&logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-17.0+-000000?style=for-the-badge&logo=apple&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Liquid_Glass-blue?style=for-the-badge&logo=swift)

**Muslim Clock** est une application iOS moderne, fluide et intelligente conçue pour accompagner les musulmans au quotidien. Développée 100% en SwiftUI, elle se distingue par son interface premium "Liquid Glass" et son algorithme exclusif de rétro-ingénierie des horaires de prière.

## ✨ Fonctionnalités Principales

### 🕋 Horaires de Prière & Smart Setup
* **Moteur Astronomique :** Intégration de la librairie `Adhan` pour des calculs hors-ligne ultra-précis.
* **Algorithme "Smart Setup" 🧠 :** Fini la configuration compliquée ! L'utilisateur saisit simplement les heures affichées à sa mosquée locale, et l'Intelligence Artificielle de l'application fait de la rétro-ingénierie pour déduire automatiquement l'angle de calcul (12°, 15°, 18°) et les ajustements de Temkine nécessaires (+/- minutes).
* **Notifications Intelligentes :** Planification par lots (Batch Scheduling) sur 14 jours via `UNUserNotificationCenter`, avec nettoyage automatique au changement de réglages.

### 🎧 Lecteur de Podcasts (Séries Audio)
* **Custom AVPlayer :** Un lecteur audio natif intégré avec support du background et du Control Center (Lock Screen / Dynamic Island).
* **Reprise Intelligente (Bookmarks) :** L'application sauvegarde la position de lecture toutes les 10 secondes. Si l'utilisateur quitte l'app, il reprendra exactement là où il s'est arrêté.
* **Progression de Série :** Les épisodes écoutés sont marqués et validés. À 100% d'une série, l'application passe automatiquement à la suivante. Menu discret pour changer de série manuellement.

### 📖 Rappels Quotidiens (Coran & Hadiths)
* **Coran à la demande :** Fetch dynamique et asynchrone (Lazy Fetching) depuis l'API `alquran.cloud` pour découvrir un nouveau verset avec sa traduction à chaque rafraîchissement.
* **Hadiths Saisonniers (Déterministes) :** Moteur d'aléatoire "seedé" par la date du jour. Le Hadith reste le même toute la journée. Un algorithme détecte les saisons (Ramadan, Vendredi, Lundi/Jeudi) pour proposer du contenu contextuel avec un ratio de 70/30.

### 📱 Widgets iOS
* **Next Prayer Widget :** Partage des données (GPS, Angles, Temkine) entre l'application et les widgets de l'écran d'accueil via `AppGroup` et `UserDefaults` scopés.

---

## 🎨 UI / UX Design : "Liquid Glass"

L'interface a été pensée selon les derniers standards d'Apple :
* **Glassmorphism :** Utilisation intensive de `.ultraThinMaterial`, de bordures lumineuses (`LinearGradient`) et d'ombres colorées pour un effet "Néon/Verre" immersif.
* **Continuous Corners :** Utilisation de `RoundedRectangle(style: .continuous)` pour des arrondis parfaits (Squircles).
* **Micro-interactions :** Animations fluides sur les changements d'état (Play/Pause), jauges de progression ultra-fines (2 pixels) et Skeleton Loading (`.redacted`) au lancement.
* **Dark Mode Forcé :** Expérience sombre garantie pour une lisibilité parfaite des couleurs d'accentuation (Orange/Blanc).

---

## 🛠 Architecture & Tech Stack

* **Langage :** Swift 5.9+
* **Framework UI :** SwiftUI
* **Architecture :** MVVM (Model-View-ViewModel) réactif avec `@EnvironmentObject` et `@AppActor` (MainActor).
* **Audio :** `AVFoundation`, `MediaPlayer` (MPNowPlayingInfoCenter).
* **Persistance :** `UserDefaults` (avec clés scopées par série audio pour éviter les fuites de mémoire) & `@AppStorage`.
* **Réseau :** `URLSession` async/await, `XMLParser` (pour les flux RSS Apple Podcasts).

---

## 🚀 Installation & Lancement

1. Clonez ce dépôt :
   ```bash
   git clone [https://github.com/votre-nom/Muslim-Clock.git](https://github.com/votre-nom/Muslim-Clock.git)
