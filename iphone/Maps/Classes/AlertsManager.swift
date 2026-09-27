// AlertsManager.swift
// mapsX – Academic proof-of-concept (tirocinio/tesi)
//
// Layer Swift: parsing del JSON degli alert e invio al bridge Objective-C++.
// Nessuna rete reale: il feed e mockato localmente per lo studio del pattern.

import Foundation

// MARK: - Data Model

/// Tipologie di allerta supportate nel PoC.
/// Il raw value Int e usato da @objc; il symbolName deve corrispondere
/// a una entry nella texture atlas SVG del progetto CoMaps.
@objc enum AlertType: Int {
  case police      = 0   // skin name: "alert-police"
  case accident    = 1   // skin name: "alert-accident"
  case trafficJam  = 2   // skin name: "alert-traffic-jam"
  case hazard      = 3   // skin name: "alert-hazard"

  var symbolName: String {
    switch self {
    case .police:     return "police-m"          // ✅ data/styles/default/*/symbols/police-m.svg
    case .accident:   return "warning-general"    // ✅ data/styles/default/*/symbols/warning-general.svg
    case .trafficJam: return "warning-unpaved_road" // ✅ avviso stradale generico
    case .hazard:     return "warning-general"    // ✅ triangolo pericolo
    }
  }
}

/// Struttura Decodable che mappa un singolo oggetto del feed JSON.
/// Esempio di payload atteso:
/// { "id": "abc", "latitude": 45.07, "longitude": 7.68, "type": "police" }
struct TrafficAlert: Decodable {
  let id: String
  let latitude: Double
  let longitude: Double
  let type: String        // "police" | "accident" | "traffic_jam" | "hazard"
  let description: String?

  var alertType: AlertType {
    switch type {
    case "police":      return .police
    case "accident":    return .accident
    case "traffic_jam": return .trafficJam
    default:            return .hazard
    }
  }
}

// MARK: - AlertsManager

/// Singolo punto di controllo per il ciclo di vita degli alert.
/// Pattern: Singleton leggero con iniezione esplicita del bridge.
///
/// @objc + NSObject: necessari affinché il compilatore Swift includa questa classe
/// in SwiftBridge.h (l'header generato automaticamente importato da MapsAppDelegate.mm).
/// Senza NSObject, Swift non può generare il wrapper ObjC.
@objc final class AlertsManager: NSObject {

  @objc static let shared = AlertsManager()

  // Riferimento opaco al bridge – inizializzato da ObjC++ tramite setBridge(_:)
  private var bridge: AlertsBridgeProtocol?

  // init() deve essere privato, ma @objc richiede che sia accessibile al runtime ObjC.
  // La soluzione è mantenere private init() e lasciare che solo `shared` venga usato.
  private override init() { super.init() }

  // MARK: - Public API

  /// Collega il bridge ObjC++.
  /// Deve essere chiamato da MapsAppDelegate prima di qualsiasi uso.
  /// @objc: espone il metodo a MapsAppDelegate.mm tramite SwiftBridge.h.
  @objc func setBridge(_ bridge: AlertsBridgeProtocol) {
    self.bridge = bridge
  }

  /// Carica il JSON mockato dal bundle (file mock_alerts.json) e spinge gli alert al core.
  /// @objc: espone il metodo a MapsAppDelegate.mm tramite SwiftBridge.h.
  @objc func loadAndPublishMockAlerts() {
    guard let url = Bundle.main.url(forResource: "mock_alerts", withExtension: "json") else {
      NSLog("[AlertsManager] Attenzione: mock_alerts.json non trovato nel bundle.")
      return
    }
    do {
      let data = try Data(contentsOf: url)
      let alerts = try JSONDecoder().decode([TrafficAlert].self, from: data)
      NSLog("[AlertsManager] Caricati %d alert dal mock.", alerts.count)
      pushToBridge(alerts)
    } catch {
      NSLog("[AlertsManager] Errore parsing JSON: %@", error.localizedDescription)
    }
  }

  /// Accetta alert gia decodificati (utile per test unitari o feed in-memory).
  func publish(alerts: [TrafficAlert]) {
    pushToBridge(alerts)
  }

  // MARK: - Private

  private func pushToBridge(_ alerts: [TrafficAlert]) {
    guard let bridge = bridge else {
      NSLog("[AlertsManager] Bridge non inizializzato. Chiama setBridge() prima.")
      return
    }
    // Converti in dizionari NSDictionary-compatibili per attraversare il confine ObjC senza
    // introdurre dipendenze @objc su struct Decodable (evita boxing e mantiene la chiarezza).
    let payload: [[String: Any]] = alerts.map { alert in
      var dict: [String: Any] = [
        "id":        alert.id,
        "latitude":  alert.latitude,
        "longitude": alert.longitude,
        "symbol":    alert.alertType.symbolName
      ]
      if let desc = alert.description { dict["description"] = desc }
      return dict
    }
    bridge.updateAlerts(payload)
  }
}
