// AlertsBootstrap.swift
// mapsX – Academic proof-of-concept (tirocinio/tesi)
//
// Classe @objc bootstrap che MapsAppDelegate.mm può chiamare con una singola
// riga senza dover conoscere AlertsManager o AlertsBridgeProtocol.
// Risolve il problema dell'ordine di compilazione Swift→ObjC: questa classe
// è l'unico punto di contatto tra ObjC++ e il layer Swift degli alert.

import Foundation

/// Espone a Objective-C++ un singolo metodo di ingresso per avviare il sistema alert.
/// MapsAppDelegate.mm chiama solo `[AlertsBootstrap startWhenReady]` — nessuna
/// altra dipendenza Swift è necessaria nel codice ObjC.
@objc final class AlertsBootstrap: NSObject {

  /// Avvia il polling e, quando il DrapeEngine è pronto, inizializza il bridge.
  /// Progettato per essere chiamato da commonInit in MapsAppDelegate.mm.
  ///
  /// Il metodo usa un timer ricorsivo sul main thread (0.2s) perché il DrapeEngine
  /// viene creato in MapViewController.viewDidLayoutSubviews, DOPO didFinishLaunching.
  /// Questa è la stessa strategia usata dal metodo isDrapeEngineCreated già presente
  /// nell'AppDelegate per altri check di timing.
  @objc static func startWhenReady() {
    pollForDrapeEngine()
  }

  // MARK: - Private

  private static func pollForDrapeEngine() {
    guard let delegate = UIApplication.shared.delegate as? MapsAppDelegate else {
      NSLog("[AlertsBootstrap] AppDelegate non trovato.")
      return
    }
    if delegate.isDrapeEngineCreated {
      initializeBridge()
    } else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        pollForDrapeEngine()
      }
    }
  }

  private static func initializeBridge() {
    let bridge = AlertsBridge.shared()
    AlertsManager.shared.setBridge(bridge)
    AlertsManager.shared.loadAndPublishMockAlerts()
    NSLog("[AlertsBootstrap] Bridge inizializzato. Alert mock pubblicati.")
  }
}
