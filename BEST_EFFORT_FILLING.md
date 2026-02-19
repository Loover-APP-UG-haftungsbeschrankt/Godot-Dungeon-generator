# Best-Effort Filling für Connector-Räume

## Problem

Connector-Räume (I, L, T-Korridore mit required connections) wurden kaum platziert, weil die atomare Füllung eine "All-or-Nothing" Strategie verwendete.

### Symptome
- "Es werden gefühlt keine Verbindungsräume gesetzt"
- T-Räume sehr selten platziert
- Wenn T-Raum platziert: "hatte auch nur 2 Verbindungen" statt 3

### Root Cause

**ALL-OR-NOTHING Strategie (VORHER):**
```gdscript
for req_conn in required_connections:
    var placed = _try_place_room_at_connection(...)
    if placed == null:
        _rollback_atomic_placement(...)  // Alles verwerfen!
        return false                      // Connector ablehnen!
```

**Problem:**
- T-Raum braucht 3 freie Positionen → sehr selten alle verfügbar
- I-Raum braucht 2 freie Positionen → oft mindestens 1 blockiert
- L-Raum braucht 2 freie Positionen → oft mindestens 1 blockiert
- Wenn EINE Connection nicht gefüllt werden kann → GANZER Connector abgelehnt

**Resultat:** Fast keine Connector-Räume im Dungeon ❌

## Lösung: Best-Effort Strategie

**BEST-EFFORT (NACHHER):**
```gdscript
var connections_satisfied = 0

for req_conn in required_connections:
    if _is_connection_satisfied(...):
        connections_satisfied += 1  // Bereits erfüllt
        continue
    
    var placed = _try_place_room_at_connection(...)
    if placed == null:
        continue  // Diese überspringen, nicht alles verwerfen!
    
    connections_satisfied += 1  // Erfolgreich gefüllt

// Platziere alle erfolgreichen Räume
for placed in placed_rooms_backup:
    _place_room(placed)

return connections_satisfied > 0  // Erfolg wenn ≥1 erfüllt
```

### Änderungen

1. **Kein Rollback bei einzelner Fehler:** `continue` statt `_rollback_atomic_placement()`
2. **Zählt erfüllte Connections:** Trackt `connections_satisfied`
3. **Erfolg bei ≥1:** `return connections_satisfied > 0` statt `return false`
4. **Platziert alle erfolgreichen:** Füllt was möglich ist, verwirft nicht alles

## Vergleich

### Vorher (All-or-Nothing)

| Raum-Typ | Required Connections | Bedingung | Häufigkeit |
|----------|---------------------|-----------|------------|
| I-Raum   | 2 (oben + unten)   | BEIDE frei | Selten ❌ |
| L-Raum   | 2 (rechts + unten) | BEIDE frei | Selten ❌ |
| T-Raum   | 3 (oben + rechts + unten) | ALLE 3 frei | Sehr selten ❌ |

**Ergebnis:** Kaum Connector-Räume platziert

### Nachher (Best-Effort)

| Raum-Typ | Required Connections | Bedingung | Häufigkeit |
|----------|---------------------|-----------|------------|
| I-Raum   | 2 (oben + unten)   | ≥1 frei | Häufig ✓ |
| L-Raum   | 2 (rechts + unten) | ≥1 frei | Häufig ✓ |
| T-Raum   | 3 (oben + rechts + unten) | ≥1 frei | Viel häufiger ✓ |

**Ergebnis:** Viele Connector-Räume platziert

## Beispiele

### Beispiel 1: T-Raum mit 2/3 Connections

```
Situation:
  [?] ← Frei
   ↓
[?]─[T]─[X] ← Blockiert
   ↓
  [?] ← Frei

VORHER:
  - TOP: Erfolg ✓
  - RIGHT: Fehler (blockiert) ✗
  - ROLLBACK: Alle verwerfen
  - Result: T-Raum NICHT platziert ❌

NACHHER:
  - TOP: Erfolg ✓ (connections_satisfied = 1)
  - RIGHT: Fehler → continue (überspringen)
  - BOTTOM: Erfolg ✓ (connections_satisfied = 2)
  - Result: T-Raum platziert mit 2 Türen ✓
  - RIGHT bleibt offen für später

DUNGEON:
  [■]
   D  ← Tür
[■]─[T]→[ ] ← Offene Connection
   D  ← Tür
  [■]
```

### Beispiel 2: I-Raum mit 1/2 Connections

```
Situation:
  [X] ← Blockiert
   ↓
  [I]
   ↓
  [?] ← Frei

VORHER:
  - TOP: Fehler (blockiert) ✗
  - ROLLBACK: Alle verwerfen
  - Result: I-Raum NICHT platziert ❌

NACHHER:
  - TOP: Fehler → continue (überspringen)
  - BOTTOM: Erfolg ✓ (connections_satisfied = 1)
  - Result: I-Raum platziert mit 1 Tür ✓
  - TOP bleibt offen für später

DUNGEON:
  [X]
   ↓
  [I] ← I-Raum ohne Tür oben
   D  ← Tür unten
  [■]
```

### Beispiel 3: L-Raum mit 2/2 Connections

```
Situation:
  [?]
   ↓
  [L]→[?]

VORHER:
  - BOTTOM: Erfolg ✓
  - RIGHT: Erfolg ✓
  - Result: L-Raum platziert mit 2 Türen ✓

NACHHER:
  - BOTTOM: Erfolg ✓ (connections_satisfied = 1)
  - RIGHT: Erfolg ✓ (connections_satisfied = 2)
  - Result: L-Raum platziert mit 2 Türen ✓

Gleich wie vorher, aber funktioniert auch mit nur 1 Connection!
```

## Garantien

### ✓ Mindestens 1 Connection erfüllt
- `connections_satisfied >= 1` Bedingung
- Verhindert isolierte Connector-Räume
- Immer mindestens 1 Tür vorhanden

### ✓ Maximale Füllung
- Versucht ALLE required connections zu füllen
- Füllt so viele wie möglich
- Nutzt verfügbaren Platz optimal

### ✓ Offene Connections für später
- Unfüllbare Connections bleiben offen
- Andere Walker können später füllen
- Organisches Dungeon-Wachstum

### ✓ Mehr Connector-Räume
- I-Räume: Häufiger platziert
- L-Räume: Häufiger platziert
- T-Räume: Viel häufiger platziert

## Technische Details

### Algorithmus

```gdscript
func _fill_required_connections_atomic(connector, walker) -> bool:
    var connections_satisfied = 0
    var placed_rooms = []
    
    for req_conn in required_connections:
        // Bereits erfüllt?
        if _is_connection_satisfied(connector, req_conn):
            connections_satisfied += 1
            continue
        
        // Versuche zu füllen
        var placed = _try_place_room_at_connection(...)
        if placed == null:
            continue  // Überspringen, nicht abbrechen!
        
        // Erfolg
        connections_satisfied += 1
        placed_rooms.append(placed)
    
    // Platziere alle erfolgreichen
    for placed in placed_rooms:
        _place_room(placed)
    
    // Erfolg wenn mindestens 1 erfüllt
    return connections_satisfied > 0
```

### Erfolgs-Kriterium

```gdscript
return connections_satisfied > 0
```

**Bedeutung:**
- `connections_satisfied = 0` → Connector NICHT platziert
- `connections_satisfied ≥ 1` → Connector platziert

**Zählt:**
- Bereits erfüllte Connections (mit Tür)
- Neu gefüllte Connections (Raum platziert)

## Auswirkungen

### Positiv ✅

1. **Mehr Connector-Räume:** T, I, L-Räume werden häufiger platziert
2. **Bessere Nutzung:** Nutzt verfügbaren Platz optimal
3. **Flexibilität:** Funktioniert auch in engen Räumen
4. **Organisches Wachstum:** Offene Connections werden später gefüllt
5. **Keine Deadlocks:** Kein komplettes Ablehnen wegen 1 Fehler

### Trade-offs ⚠️

1. **Unvollständige Connectors:** Manche Connectors haben nicht alle Türen sofort
2. **Offene Connections:** Required connections können temporär offen sein
3. **Spätere Füllung:** Walker müssen später offene Connections finden

**Aber:** Diese Trade-offs sind akzeptabel, da:
- Alternative ist: Überhaupt keine Connector-Räume ❌
- Offene Connections werden von Walkern gefüllt
- Mehr Dungeon-Variabilität

## Ergebnis

**✅ Problem gelöst!**

- Connector-Räume werden jetzt häufig platziert
- T-Räume bekommen 1, 2 oder 3 Türen (je nach Platz)
- I-Räume bekommen 1 oder 2 Türen
- L-Räume bekommen 1 oder 2 Türen
- Dungeons haben mehr Verbindungen und sind interessanter

**Keine "gefühlt keine Verbindungsräume" mehr!**
