# Verwendungsanleitung (Usage Guide)

## Schnellstart

### 1. Projekt in Godot öffnen

1. Öffne Godot 4.3 oder höher
2. Wähle "Import" und navigiere zu diesem Projektordner
3. Klicke auf "Import & Edit"

### 2. Beispiele ausführen

Es gibt drei Beispiel-Szenen, die verschiedene Aspekte des Generators demonstrieren:

#### Basic Example (`example_usage.tscn`)
- Einfaches Beispiel mit grundlegender Konfiguration
- Zeigt verschiedene Raumgrößen und Korridore
- Konsolen-Ausgabe des generierten Dungeons

**Ausführen:** 
1. Öffne `example_usage.tscn`
2. Drücke F6 (Run Current Scene)
3. Prüfe die Konsole für die Ausgabe

#### Advanced Example (`advanced_example.tscn`)
- Fortgeschrittenes Beispiel mit komplexeren Räumen
- Demonstriert T- und Kreuz-Junctions
- Zeigt Prefab-Platzierung mit Bedingungen

**Ausführen:**
1. Öffne `advanced_example.tscn`
2. Drücke F6
3. Prüfe die Konsole für detaillierte Statistiken

#### Visual Example (`visual_example.tscn`)
- Visuelle Darstellung des generierten Dungeons
- Zeigt den Dungeon auf dem Bildschirm
- Drücke SPACE zum Neu-Generieren

**Ausführen:**
1. Öffne `visual_example.tscn`
2. Drücke F6
3. Siehe den Dungeon auf dem Bildschirm
4. Drücke SPACE zum Neu-Generieren

## Eigenen Generator erstellen

### Schritt 1: Scene erstellen

Erstelle eine neue Scene mit einem Node2D oder Node als Root:

```
Scene
├── Node (oder Node2D)
│   └── DungeonGenerator (Node mit dungeon_generator.gd)
```

### Schritt 2: Script hinzufügen

Füge ein Script zu deinem Root-Node hinzu:

```gdscript
extends Node

@onready var generator: DungeonGenerator = $DungeonGenerator

func _ready():
    # Tile-Typen definieren
    var wall_type = MetaTileType.new("wall", "Wand")
    var room_type = MetaTileType.new("room", "Raumboden")
    var corridor_type = MetaTileType.new("corridor", "Korridor")
    
    # Räume erstellen
    var rooms = []
    
    # Kleiner Raum
    var small_room = MetaRoom.new("SmallRoom", 5, 5)
    for y in range(5):
        for x in range(5):
            if x == 0 or x == 4 or y == 0 or y == 4:
                small_room.set_tile(x, y, wall_type)
            else:
                small_room.set_tile(x, y, room_type)
    rooms.append(small_room)
    
    # Korridor
    var corridor = MetaRoom.new("Corridor", 3, 1)
    for x in range(3):
        corridor.set_tile(x, 0, corridor_type)
    rooms.append(corridor)
    
    # Generator konfigurieren
    generator.available_rooms = rooms
    generator.grid_width = 30
    generator.grid_height = 30
    generator.min_grid_elements = 100
    
    # Signal verbinden
    generator.generation_complete.connect(_on_generation_complete)
    
    # Generierung starten
    generator.generate_dungeon()

func _on_generation_complete(grid: Array):
    print("Dungeon generiert!")
    # Hier kannst du mit dem Grid arbeiten
    # z.B. Tiles platzieren, Enemies spawnen, etc.
```

### Schritt 3: Parameter anpassen

Die wichtigsten Parameter:

| Parameter | Beschreibung | Empfohlener Wert |
|-----------|-------------|------------------|
| `grid_width` | Breite des Grids | 20-50 |
| `grid_height` | Höhe des Grids | 20-50 |
| `min_grid_elements` | Mindest gefüllte Tiles | 30-50% der Grid-Größe |
| `max_attempts_per_placement` | Versuche pro Raum | 10-20 |

**Beispiel:**
```gdscript
generator.grid_width = 40
generator.grid_height = 30
generator.min_grid_elements = 200  # ~17% von 40*30
```

## Eigene Räume erstellen

### Rechteckiger Raum

```gdscript
func create_rectangular_room(width: int, height: int) -> MetaRoom:
    var room = MetaRoom.new("Room_%dx%d" % [width, height], width, height)
    
    for y in range(height):
        for x in range(width):
            if x == 0 or x == width - 1 or y == 0 or y == height - 1:
                room.set_tile(x, y, wall_type)
            else:
                room.set_tile(x, y, room_type)
    
    return room
```

### Korridor

```gdscript
func create_corridor(length: int, vertical: bool = false) -> MetaRoom:
    var width = 1 if vertical else length
    var height = length if vertical else 1
    var name = "Corridor%s_%d" % ["V" if vertical else "H", length]
    
    var corridor = MetaRoom.new(name, width, height)
    
    for y in range(height):
        for x in range(width):
            corridor.set_tile(x, y, corridor_type)
    
    return corridor
```

### L-förmiger Raum

```gdscript
func create_l_room() -> MetaRoom:
    var room = MetaRoom.new("LRoom", 5, 5)
    
    # Nur die L-Form füllen
    for y in range(5):
        for x in range(5):
            # Obere Hälfte voll, untere Hälfte nur links
            if y < 3 or x < 2:
                if x == 0 or y == 0 or (y == 4 and x < 2) or (x == 4 and y < 3):
                    room.set_tile(x, y, wall_type)
                else:
                    room.set_tile(x, y, room_type)
    
    return room
```

## Prefabs mit Bedingungen

### Tür zwischen Korridoren

```gdscript
func create_door_prefab() -> MetaPrefab:
    var door = MetaPrefab.new("Door", 1, 1)
    door.tile_type = door_type
    
    # Tür braucht Korridore oben und unten
    door.set_neighbor_condition(MetaPrefab.Direction.NORTH, corridor_type)
    door.set_neighbor_condition(MetaPrefab.Direction.SOUTH, corridor_type)
    
    door.allow_rotation = true  # Kann auch horizontal sein
    
    return door
```

### Tür in Wand

```gdscript
func create_wall_door_prefab() -> MetaPrefab:
    var door = MetaPrefab.new("WallDoor", 1, 1)
    door.tile_type = door_type
    
    # Tür braucht Wände links und rechts, Räume oben und unten
    door.set_neighbor_condition(MetaPrefab.Direction.WEST, wall_type)
    door.set_neighbor_condition(MetaPrefab.Direction.EAST, wall_type)
    door.set_neighbor_condition(MetaPrefab.Direction.NORTH, room_type)
    door.set_neighbor_condition(MetaPrefab.Direction.SOUTH, corridor_type)
    
    door.allow_rotation = true
    
    return door
```

## Dungeon visualisieren

### Option 1: TileMap verwenden

```gdscript
@onready var tilemap: TileMap = $TileMap

func _on_generation_complete(grid: Array):
    for y in range(len(grid)):
        for x in range(len(grid[0])):
            var tile = grid[y][x]
            if tile != null:
                var tile_id = _get_tile_id(tile.type_name)
                tilemap.set_cell(0, Vector2i(x, y), tile_id, Vector2i(0, 0))

func _get_tile_id(type_name: String) -> int:
    match type_name:
        "wall": return 0
        "room": return 1
        "corridor": return 2
        "door": return 3
        _: return -1
```

### Option 2: Sprites spawnen

```gdscript
const TILE_SIZE = 32

func _on_generation_complete(grid: Array):
    for y in range(len(grid)):
        for x in range(len(grid[0])):
            var tile = grid[y][x]
            if tile != null:
                var sprite = Sprite2D.new()
                sprite.texture = _get_texture(tile.type_name)
                sprite.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
                add_child(sprite)

func _get_texture(type_name: String) -> Texture2D:
    # Lade Textur basierend auf Typ
    return load("res://textures/%s.png" % type_name)
```

## Tipps & Best Practices

### 1. Raum-Gewichtung

- Kleine Räume/Korridore: Gewicht 3-5
- Mittlere Räume: Gewicht 1-2
- Große Räume: Gewicht 0.5-1
- Spezial-Räume: Gewicht 0.1-0.5

### 2. Grid-Größe

- Für kleine Dungeons: 20x20 bis 30x30
- Für mittlere Dungeons: 30x30 bis 50x50
- Für große Dungeons: 50x50+

**Tipp:** Größere Grids brauchen mehr `min_grid_elements`

### 3. Min Grid Elements

- Empfehlung: 10-30% der Grid-Größe
- Zu wenig: Dungeon kann zu klein sein
- Zu viel: Generierung kann zu lange dauern

### 4. Debugging

```gdscript
# Grid in Konsole ausgeben
generator.print_grid()

# Statistiken ausgeben
var stats = generator.get_stats()
print("Filled: %d, Rooms: %d" % [stats.filled_tiles, stats.rooms_placed])
```

### 5. Performance

- Verwende kleinere Grid-Größen für schnellere Generierung
- Reduziere `max_attempts_per_placement` wenn Generierung zu langsam
- Verwende weniger verschiedene Raum-Typen für schnellere Auswahl

## Häufige Probleme

### Problem: Generierung schlägt fehl

**Lösung:**
- Erhöhe `max_attempts_per_placement`
- Reduziere `min_grid_elements`
- Füge mehr kleine Räume/Korridore hinzu
- Vergrößere das Grid

### Problem: Dungeon ist zu klein

**Lösung:**
- Erhöhe `min_grid_elements`
- Füge mehr Räume mit höherem Gewicht hinzu

### Problem: Nur ein Raum-Typ wird platziert

**Lösung:**
- Prüfe die Gewichtungen (zu unterschiedlich?)
- Füge mehr Variation in Raum-Größen hinzu

### Problem: Räume überlappen sich

**Lösung:**
- Das sollte nicht passieren! Wenn doch, ist es ein Bug
- Prüfe dass `can_place_at` korrekt implementiert ist

## Weiterführende Themen

### Dungeon Post-Processing

Nach der Generierung kannst du:
- Türen zwischen Räumen platzieren
- Enemies spawnen
- Items platzieren
- Beleuchtung hinzufügen

### Mehrere Etagen

Generiere mehrere Dungeons und verbinde sie:

```gdscript
var dungeons = []
for i in range(3):
    generator.generate_dungeon()
    await generator.generation_complete
    dungeons.append(generator.get_grid().duplicate(true))
```

### Speichern/Laden

```gdscript
func save_dungeon(grid: Array, filename: String):
    var file = FileAccess.open(filename, FileAccess.WRITE)
    file.store_var(grid)
    file.close()

func load_dungeon(filename: String) -> Array:
    var file = FileAccess.open(filename, FileAccess.READ)
    var grid = file.get_var()
    file.close()
    return grid
```

## Support

Bei Fragen oder Problemen:
1. Prüfe die API-Dokumentation (API.md)
2. Schaue dir die Beispiele an
3. Erstelle ein Issue auf GitHub
