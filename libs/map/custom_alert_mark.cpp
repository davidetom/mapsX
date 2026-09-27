// custom_alert_mark.cpp
// mapsX – Academic proof-of-concept (tirocinio/tesi)
//
// POSIZIONE SUGGERITA NEL PROGETTO: libs/map/custom_alert_mark.cpp
//
// Ricordarsi di aggiungere in libs/map/CMakeLists.txt:
//   custom_alert_mark.cpp

#include "map/custom_alert_mark.hpp"
#include "drape/pointers.hpp"  // make_unique_dp

// ────────────────────────────────────────────────────────────────────────────
// Nota sui valori kml::MarkId:
//   UserMark::UserMark(m2::PointD const & ptOrg, UserMark::Type type)
//   è il costruttore da usare quando il BookmarkManager non ha ancora assegnato
//   un ID. La versione a 3 parametri (con kml::MarkId) è usata internamente dal
//   pool di allocazione: non va chiamata direttamente dal bridge.
// ────────────────────────────────────────────────────────────────────────────

CustomAlertMark::CustomAlertMark(m2::PointD const & ptOrg)
  : UserMark(ptOrg, UserMark::Type::CUSTOM_ALERT)
  , m_symbolName("warning-general")  // fallback verificato: data/styles/default/*/symbols/warning-general.svg

{}

void CustomAlertMark::SetSymbolName(std::string const & symbolName)
{
  if (m_symbolName == symbolName)
    return;  // evita SetDirty() se il simbolo non cambia davvero
  m_symbolName = symbolName;
  SetDirty();
}

void CustomAlertMark::SetPivot(m2::PointD const & pt)
{
  if (m_ptOrg == pt)
    return;
  m_ptOrg = pt;
  SetDirty();
}

drape_ptr<df::UserPointMark::SymbolNameZoomInfo> CustomAlertMark::GetSymbolNames() const
{
  // SymbolNameZoomInfo e' un alias per std::map<int8_t, std::string>:
  //   chiave   = livello di zoom a partire dal quale il simbolo e' attivo
  //   valore   = nome del file SVG nel pacchetto grafico Drape
  //
  // Strategia multi-zoom:
  //   zoom  9 -> simbolo piccolo (es. "alert-hazard-s")  [se disponibile]
  //   zoom 14 -> simbolo grande/dettagliato
  //
  // Per il PoC usiamo un singolo simbolo dalla stessa entry per tutti gli zoom;
  // in una versione produzione si potrebbe creare una variante "_small" per zoom < 12.
  auto symbols = make_unique_dp<SymbolNameZoomInfo>();
  symbols->insert({9 /* zoomLevel */, m_symbolName});
  return symbols;
}
