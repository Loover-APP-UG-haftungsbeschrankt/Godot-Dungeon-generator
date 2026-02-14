# Godot Dungeon Generator

Ein flexibler Dungeon-Generator für Roguelike-Spiele in Godot 4.x mit GDScript. Das System verwendet Meta-Prefabs und einen Random Room Walker Algorithmus.

## Features

- **Meta-Prefab System**: Definiere wiederverwendbare Raum-Templates mit Platzierungsbedingungen
- **Rotation Support**: Automatische Rotation von Prefabs (90°, 180°, 270°)
- **Flexible Bedingungen**: Definiere welche Tile-Typen um ein Prefab herum sein müssen
- **Random Room Walker**: Intelligenter Algorithmus der Räume zufällig platziert
- **Konfigurierbar**: Kontrolle über Grid-Größe, Mindestanzahl an Tiles, etc.

## Architektur

### Hauptkomponenten

1. **MetaTileType** (`meta_tile_type.gd`)
   - Definiert einen Typ von Meta-Tile (z.B. Wand, Korridor, Raum, Tür)
   - Wird für Matching-Bedingungen verwendet

2. **MetaPrefab** (`meta_prefab.gd`)
   - Stellt ein Prefab dar, das auf dem Meta-Grid platziert werden kann
   - Unterstützt:
     - Variable Größe (1x1, 2x2, etc.)
     - Bedingungen für benachbarte Tiles
     - Rotation (90°, 180°, 270°)
   - Prüft automatisch ob Platzierung möglich ist

3. **MetaRoom** (`meta_room.gd`)
   - Repräsentiert ein Raum-Template
   - Enthält ein Layout-Grid aus MetaTileTypes
   - Kann auf das Meta-Grid platziert werden
   - Unterstützt Gewichtung für zufällige Auswahl

4. **DungeonGenerator** (`dungeon_generator.gd`)
   - Hauptgenerator mit Random Room Walker Algorithmus
   - Features:
     - Konfigurierbare Grid-Größe
     - Minimum Anzahl von Grid-Elementen
     - Retry-Logik: 10 Versuche, dann zufälligen existierenden Raum wählen
     - Signals für Erfolg/Fehler

## Verwendung

### Basis-Setup

```gdscript
extends Node

@onready var generator: DungeonGenerator = $DungeonGenerator

func _ready():
    # Tile-Typen erstellen
    var wall_type = MetaTileType.new("wall", "Eine feste Wand")
    var corridor_type = MetaTileType.new("corridor", "Ein Korridor")
    var room_type = MetaTileType.new("room", "Ein Raumboden")
    
    # Räume erstellen
    var rooms = []
    
    # Kleiner Raum (3x3)
    var small_room = MetaRoom.new("SmallRoom", 3, 3)
    for y in range(3):
        for x in range(3):
            if x == 0 or x == 2 or y == 0 or y == 2:
                small_room.set_tile(x, y, wall_type)
            else:
                small_room.set_tile(x, y, room_type)
    rooms.append(small_room)
    
    # Generator konfigurieren
    generator.available_rooms = rooms
    generator.grid_width = 30
    generator.grid_height = 30
    generator.min_grid_elements = 80
    
    # Signals verbinden
    generator.generation_complete.connect(_on_generation_complete)
    
    # Generierung starten
    generator.generate_dungeon()

func _on_generation_complete(grid: Array):
    print("Dungeon generiert!")
    var stats = generator.get_stats()
    print("Statistik: ", stats)
```

### Meta-Prefab mit Bedingungen

```gdscript
# Erstelle einen "Wand mit Tür" Prefab
var wall_door = MetaPrefab.new("WallDoor", 1, 1)
wall_door.tile_type = door_type

# Bedingungen setzen:
# - Oben: Korridor
# - Unten: Korridor
# - Mitte: Wand
wall_door.set_neighbor_condition(MetaPrefab.Direction.NORTH, corridor_type)
wall_door.set_neighbor_condition(MetaPrefab.Direction.SOUTH, corridor_type)

# Rotation erlauben
wall_door.allow_rotation = true

# Prüfen ob Platzierung möglich
if wall_door.can_place_at(grid, grid_width, grid_height, x, y, 90):
    # Kann mit 90° Rotation platziert werden
    pass
```

### Raum-Templates mit Gewichtung

```gdscript
# Raum mit höherer Wahrscheinlichkeit
var common_room = MetaRoom.new("CommonRoom", 3, 3)
common_room.weight = 3.0  # 3x wahrscheinlicher als Gewicht 1.0

# Seltener Raum
var rare_room = MetaRoom.new("RareRoom", 5, 5)
rare_room.weight = 0.5  # Halb so wahrscheinlich

# Minimum/Maximum Anzahl
common_room.min_count = 2  # Mindestens 2 in jedem Dungeon
rare_room.max_count = 1    # Maximal 1 in jedem Dungeon
```

## Algorithmus: Random Room Walker

Der Generator verwendet einen Walker-basierten Ansatz:

1. **Initialisierung**: Walker startet in der Mitte des Grids
2. **Raum-Platzierung**: 
   - Wähle zufälligen Raum basierend auf Gewichtung
   - Versuche Platzierung in der Nähe des Walkers
   - Bis zu 10 Versuche pro Position
3. **Bei Fehler**: 
   - Nach 10 erfolglosen Versuchen: Wähle zufälligen bereits platzierten Raum
   - Bewege Walker dorthin und versuche erneut
4. **Abschluss**: 
   - Generierung läuft bis `min_grid_elements` erreicht ist
   - Oder maximale Iterationen überschritten werden

## Konfiguration

### DungeonGenerator Properties

```gdscript
@export var grid_width: int = 20              # Breite des Meta-Grids
@export var grid_height: int = 20             # Höhe des Meta-Grids
@export var min_grid_elements: int = 50       # Minimum gefüllte Tiles
@export var max_attempts_per_placement: int = 10  # Versuche pro Raum
@export var available_rooms: Array[MetaRoom] = [] # Verfügbare Räume
```

## Beispiel

Ein vollständiges Beispiel findet sich in:
- `example_usage.gd` - Script mit Beispiel-Setup
- `example_usage.tscn` - Scene zum Testen

Um das Beispiel zu starten:
1. Öffne das Projekt in Godot 4.x
2. Öffne `example_usage.tscn`
3. Drücke F6 zum Starten der Scene
4. Prüfe die Konsole für Debug-Ausgabe

## Erweiterte Funktionen

### Custom Tile Types

```gdscript
class_name MyCustomTileType
extends MetaTileType

var special_property: String = ""

func _init(name: String, desc: String, prop: String):
    super._init(name, desc)
    special_property = prop
```

### Grid Visualisierung

```gdscript
func visualize_grid(grid: Array):
    for y in range(len(grid)):
        for x in range(len(grid[0])):
            var tile = grid[y][x]
            if tile != null:
                # Erstelle visuelle Repräsentation
                var sprite = Sprite2D.new()
                sprite.position = Vector2(x * 32, y * 32)
                # ... weitere Konfiguration
                add_child(sprite)
```

## Lizenz

Dieses Projekt ist Open Source. Siehe LICENSE Datei für Details.

## Beiträge

Beiträge sind willkommen! Bitte erstelle einen Pull Request oder öffne ein Issue.
