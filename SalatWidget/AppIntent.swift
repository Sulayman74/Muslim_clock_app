import AppIntents
import Foundation // Remplace WidgetKit par Foundation ici

struct ToggleSunnahIntent: AppIntent {
    static var title: LocalizedStringResource = "Valider une Sunnah"
    
    @Parameter(title: "Nom de la Sunnah")
    var sunnahName: String
    
    // ⚠️ AJOUT OBLIGATOIRE POUR iOS 17
    init() {}
    
    init(sunnahName: String) {
        self.sunnahName = sunnahName
    }
    
    func perform() async throws -> some IntentResult {
        // ⚠️ ATTENTION AU NOM DU GROUPE
        // Sur iOS, les App Groups commencent (presque) toujours par "group."
        // Vérifie bien dans tes "Capabilities" sur Xcode que c'est le bon nom !
        guard let sharedDefaults = UserDefaults(suiteName: "group.kappsi.Muslim-Clock") else {
            return .result()
        }
        
        let currentState = sharedDefaults.bool(forKey: sunnahName)
        sharedDefaults.set(!currentState, forKey: sunnahName)
        
        return .result()
    }
}
