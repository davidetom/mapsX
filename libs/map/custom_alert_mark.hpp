// custom_alert_mark.hpp
// mapsX – Academic proof-of-concept (tirocinio/tesi)
//
// Definizione di CustomAlertMark: un UserMark specializzato per rendere
// visibili le allerte di traffico (polizia, incidenti, ecc.) sulla mappa CoMaps.
//
// POSIZIONE SUGGERITA NEL PROGETTO: libs/map/custom_alert_mark.hpp
//
// COME INTEGRARSI CON IL SISTEMA ESISTENTE:
//   1. Aggiungere CUSTOM_ALERT all'enum UserMark::Type in libs/map/user_mark.hpp
//   2. Registrare la nuova costante di priorità nell'enum UserMark::Priority
//   3. Linkare il CMakeLists.txt con custom_alert_mark.cpp (vedi sotto)

#pragma once

#include "map/user_mark.hpp"           // UserMark base class
#include "drape_frontend/user_marks_provider.hpp"  // SymbolNameZoomInfo
#include "drape_frontend/render_state_extension.hpp" // df::DepthLayer
#include "drape/utils/projection.hpp"  // dp::kMaxDepth (= 25000.0f)
#include "geometry/point2d.hpp"        // m2::PointD

#include <string>

// ────────────────────────────────────────────────────────────────────────────
// STEP 1: Aggiungere al file libs/map/user_mark.hpp
//
//   Nell'enum Priority aggiungere dopo TrafficLight:
//     CustomAlert,
//
//   Nell'enum Type aggiungere dopo TRAFFIC_LIGHT:
//     CUSTOM_ALERT,
//
//   (Il valore numerico di CUSTOM_ALERT sarà USER_MARK_TYPES_COUNT-1 prima della sentinella)
// ────────────────────────────────────────────────────────────────────────────

/// Rappresenta un singolo punto di allerta traffico sulla mappa CoMaps.
///
/// Il Drape engine disegna il mark usando GetSymbolNames(), che restituisce
/// una SymbolNameZoomInfo: una mappa <zoomLevel -> nomeIcona> che dice al
/// renderer quale sprites SVG usare ad ogni livello di zoom.
///
/// Ciclo di vita:
///   Creazione  → AlertsBridge::updateAlerts via BookmarkManager::EditSession::CreateUserMark<>
///   Rimozione  → AlertsBridge::clearAllAlerts via EditSession::ClearGroup
///
class CustomAlertMark final : public UserMark
{
public:
  // ── Costruttori ──────────────────────────────────────────────────────────

  /// Costruttore primario: il BookmarkManager lo chiama tramite CreateUserMark<CustomAlertMark>.
  /// @param ptOrg Posizione in coordinate Mercatore (già convertita dal bridge).
  explicit CustomAlertMark(m2::PointD const & ptOrg);

  // ── Setters (chiamati dal bridge dopo la creazione) ───────────────────────

  /// Imposta il nome del simbolo SVG da renderizzare.
  /// Il nome deve corrispondere a una entry nel file skin del progetto:
  ///   data/styles/[clear|night]/style.mapcss  o  data/symbols/
  /// Esempi validi: "alert-police", "alert-accident", "alert-traffic-jam"
  void SetSymbolName(std::string const & symbolName);

  /// Sposta il mark a una nuova posizione Mercatore (per update incrementali).
  /// Chiama internamente SetDirty() per forzare il re-render.
  void SetPivot(m2::PointD const & pt);

  // ── UserMark / df::UserPointMark overrides ───────────────────────────────

  /// Restituisce la mappa zoom→simbolo usata dal renderer Drape.
  /// Il simbolo è visibile da zoom 1 in poi (personalizzabile).
  drape_ptr<SymbolNameZoomInfo> GetSymbolNames() const override;

  /// Priorità di rendering: più alta = meno soppresso dai meccanismi di displacement.
  /// CustomAlert è meno critico di SpeedCamera ma più visibile di Default.
  uint16_t GetPriority() const override
  {
    return static_cast<uint16_t>(Priority::CustomAlert);
  }

  /// Zoom minimo di apparizione del marker (adattare alla scala urbana).
  int GetMinZoom() const override { return 9; }

  /// Il simbolo "compete" con le POI della mappa per lo spazio a schermo.
  bool SymbolIsPOI() const override { return true; }

  /// Non displaceable: l'alert deve essere sempre visibile, anche se sovrappone altri simboli.
  bool IsNonDisplaceable() const override { return true; }

  /// Layer di profondità: SearchMarkLayer è il layer più alto disponibile per i mark
  /// (sopra GeometryLayer, Geometry3dLayer/edifici 3D, OverlayLayer, UserMarkLayer,
  ///  RoutingBottomMarkLayer e RoutingMarkLayer). È lo stesso layer usato dai risultati
  ///  di ricerca e dagli avvisi di traffico nativi di CoMaps.
  ///
  ///  Stack completo (dal basso all'alto):
  ///    GeometryLayer → Geometry3dLayer → UserLineLayer → OverlayLayer
  ///    → UserMarkLayer → RoutingBottomMarkLayer → RoutingMarkLayer
  ///    → SearchMarkLayer  ← noi siamo qui
  ///    → GuiLayer (HUD, non accessibile ai mark)
  df::DepthLayer GetDepthLayer() const override
  {
    return df::DepthLayer::SearchMarkLayer;
  }

  /// Profondità all'interno del layer: kMaxDepth garantisce che il mark sia in cima
  /// anche rispetto ad altri SearchMark eventualmente presenti nella stessa area.
  float GetDepth() const override { return dp::kMaxDepth; }

  /// Gli alert non devono apparire nei risultati di ricerca.
  bool IsAvailableForSearch() const override { return false; }

  /// Mostra una piccola animazione "bounce" quando il mark appare per la prima volta.
  bool HasCreationAnimation() const override { return true; }

private:
  std::string m_symbolName;  ///< Nome del simbolo SVG attivo (es. "alert-police")
};
