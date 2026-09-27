// AlertsBridgeProtocol.swift
// mapsX – Academic proof-of-concept (tirocinio/tesi)
//
// Protocollo Swift che descrive il contratto del bridge verso il core C++.
// Permette di isolare AlertsManager dalla dipendenza diretta su AlertsBridge
// e rende il codice testabile tramite mock.

import Foundation

/// Il bridge deve implementare questo protocollo per ricevere alert da Swift.
@objc protocol AlertsBridgeProtocol {
  /// Riceve un array di dizionari con chiavi:
  ///   "id"          – String, identificatore univoco dell'alert
  ///   "latitude"    – Double, gradi decimali WGS84
  ///   "longitude"   – Double, gradi decimali WGS84
  ///   "symbol"      – String, nome del simbolo Drape (es. "alert-police")
  ///   "description" – String? (opzionale)
  func updateAlerts(_ alerts: [[String: Any]])

  /// Rimuove tutti gli alert correntemente visualizzati sulla mappa.
  func clearAllAlerts()
}
