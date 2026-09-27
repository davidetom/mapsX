// AlertsBridge.mm
// mapsX – Academic proof-of-concept (tirocinio/tesi)
//
// Implementazione Objective-C++ del bridge.
// Questo file DEVE avere estensione .mm per mixare ObjC e C++.
//
// Dipendenze C++ chiave:
//   - GetFramework()            → iphone/CoreApi/CoreApi/Framework/Framework.h
//   - mercator::FromLatLon()    → libs/geometry/mercator.hpp
//   - BookmarkManager           → libs/map/bookmark_manager.hpp
//   - CustomAlertMark           → libs/map/custom_alert_mark.hpp  (file che creiamo noi)

#import "AlertsBridge.h"

// SwiftBridge.h è l'header generato automaticamente da Xcode che contiene le
// interfacce ObjC di tutte le classi/protocolli Swift marcati @objc nel target Maps.
// È NECESSARIO importarlo qui (non solo nella Bridging-Header) perché:
//   - AlertsBridge.h usa solo la forward declaration "@protocol AlertsBridgeProtocol;"
//   - Il compilatore ObjC++ ha bisogno della definizione COMPLETA del protocollo
//     per emettere il symbol _OBJC_PROTOCOL_$_AlertsBridgeProtocol nel file oggetto.
//   - Senza questo import, il linker trova un riferimento non risolto al symbol.
#import "SwiftBridge.h"

// ── CoreApi / Framework ──────────────────────────────────────────────────────
#import <CoreApi/Framework.h>          // espone: Framework & GetFramework()

// ── C++ headers ─────────────────────────────────────────────────────────────
#include "geometry/mercator.hpp"       // mercator::FromLatLon(lat, lon) -> m2::PointD
#include "map/bookmark_manager.hpp"    // BookmarkManager, EditSession
#include "map/custom_alert_mark.hpp"   // CustomAlertMark (definita da noi)
#include "kml/type_utils.hpp"          // kml::MarkId, kml::MarkGroupId

// ── STL ─────────────────────────────────────────────────────────────────────
#include <string>
#include <vector>
#include <unordered_map>

// ────────────────────────────────────────────────────────────────────────────
// MARK: - AlertsBridge implementation
// ────────────────────────────────────────────────────────────────────────────

@implementation AlertsBridge {
  // Mappa id-alert (NSString) -> kml::MarkId per poter fare update/remove incrementali.
  // Viene modificata esclusivamente sul main thread (o con lock se si porta su background).
  std::unordered_map<std::string, kml::MarkId> _alertMarkIds;
}

+ (instancetype)shared {
  static AlertsBridge * instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[AlertsBridge alloc] init];
  });
  return instance;
}

// ────────────────────────────────────────────────────────────────────────────
// MARK: - updateAlerts:
// ────────────────────────────────────────────────────────────────────────────

- (void)updateAlerts:(NSArray<NSDictionary *> *)alerts {
  // Gli user mark del Framework vivono sul thread principale.
  dispatch_async(dispatch_get_main_queue(), ^{
    [self _updateAlertsOnMain:alerts];
  });
}

- (void)_updateAlertsOnMain:(NSArray<NSDictionary *> *)alerts {
  Framework & f = GetFramework();
  BookmarkManager & bm = f.GetBookmarkManager();

  // Apriamo una EditSession: garantisce che le modifiche siano atomiche e che
  // al termine venga chiamato automaticamente NotifyChanges() (via RAII nel dtor).
  auto session = bm.GetEditSession();

  // Costruiamo l'insieme degli id del payload corrente per calcolare le rimozioni.
  std::unordered_map<std::string, NSDictionary *> incomingById;
  for (NSDictionary * dict in alerts) {
    NSString * alertId = dict[@"id"];
    if (!alertId) continue;
    incomingById[alertId.UTF8String] = dict;
  }

  // ── Rimuovi alert che non sono più nel feed ────────────────────────────────
  std::vector<std::string> toRemove;
  for (auto const & [alertId, markId] : _alertMarkIds) {
    if (incomingById.find(alertId) == incomingById.end())
      toRemove.push_back(alertId);
  }
  for (auto const & alertId : toRemove) {
    session.DeleteUserMark(_alertMarkIds[alertId]);
    _alertMarkIds.erase(alertId);
  }

  // ── Crea o aggiorna i mark del feed corrente ──────────────────────────────
  for (auto const & [alertId, dict] : incomingById) {
    double const lat = [dict[@"latitude"]  doubleValue];
    double const lon = [dict[@"longitude"] doubleValue];
    NSString * symbol = dict[@"symbol"] ?: @"alert-hazard";

    // Conversione WGS84 -> Web-Mercator (m2::PointD)
    m2::PointD const pt = mercator::FromLatLon(lat, lon);

    auto it = _alertMarkIds.find(alertId);
    if (it == _alertMarkIds.end()) {
      // ── CREAZIONE: nuovo alert ─────────────────────────────────────────────
      // CreateUserMark alloca il mark nel pool del BookmarkManager e restituisce
      // un puntatore raw; la ownership rimane al BookmarkManager stesso.
      CustomAlertMark * mark = session.CreateUserMark<CustomAlertMark>(pt);
      mark->SetSymbolName(symbol.UTF8String);
      _alertMarkIds[alertId] = mark->GetId();
    } else {
      // ── AGGIORNAMENTO: sposta il mark o cambia il simbolo ─────────────────
      // GetMarkForEdit ottiene un puntatore mutabile al mark esistente e
      // chiama SetDirty() internamente, forzando un re-render Drape.
      CustomAlertMark * mark = session.GetMarkForEdit<CustomAlertMark>(it->second);
      if (mark) {
        mark->SetPivot(pt);
        mark->SetSymbolName(symbol.UTF8String);
      }
    }
  }

  // La EditSession chiama automaticamente NotifyChanges() nel suo distruttore,
  // invalidando il layer UserMark nel motore Drape. Non serve chiamarlo a mano.
}

// ────────────────────────────────────────────────────────────────────────────
// MARK: - clearAllAlerts
// ────────────────────────────────────────────────────────────────────────────

- (void)clearAllAlerts {
  dispatch_async(dispatch_get_main_queue(), ^{
    Framework & f = GetFramework();
    BookmarkManager & bm = f.GetBookmarkManager();
    auto session = bm.GetEditSession();
    // ClearGroup rimuove tutti i mark di tipo CUSTOM_ALERT in una sola operazione,
    // più efficiente di N chiamate singole a DeleteUserMark.
    session.ClearGroup(UserMark::Type::CUSTOM_ALERT);
    self->_alertMarkIds.clear();
  });
}

@end
