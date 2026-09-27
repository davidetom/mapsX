// AlertsBridge.h
// mapsX – Academic proof-of-concept (tirocinio/tesi)
//
// Header Objective-C del bridge. Esposto a Swift tramite il Bridging-Header.
// Non contiene C++ per rimanere puro ObjC (il .mm si occupa del lato C++).

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Bridge tra il layer Swift (AlertsManager) e il core C++ di CoMaps.
/// Si occupa di:
///   1. Ricevere i dizionari Swift contenenti le coordinate WGS84 e il tipo di alert.
///   2. Convertire lat/lon -> m2::PointD (proiezione Web-Mercator).
///   3. Creare/aggiornare oggetti CustomAlertMark nel BookmarkManager del Framework.
///   4. Notificare il motore Drape per ridisegnare i layer.
// AlertsBridgeProtocol è definito in AlertsBridgeProtocol.swift come @objc protocol.
// Il compilatore Swift lo genera in SwiftBridge.h. Qui ne facciamo una forward
// declaration per poter dichiarare la conformità nell'interfaccia ObjC senza
// dipendere dall'ordine di compilazione Swift→ObjC.
@protocol AlertsBridgeProtocol;

@interface AlertsBridge : NSObject <AlertsBridgeProtocol>

/// Singleton – necessario perché il lifetime deve coincidere con quello del Framework C++.
+ (instancetype)shared;

/// Chiamata da AlertsManager.swift con i dati già validati.
/// @param alerts Array di NSDictionary con chiavi: id, latitude, longitude, symbol, description?
- (void)updateAlerts:(NSArray<NSDictionary *> *)alerts;

/// Svuota il layer degli alert dalla mappa e deallocare i UserMark.
- (void)clearAllAlerts;

@end

NS_ASSUME_NONNULL_END
