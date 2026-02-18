# Godot Dungeon Generator - Architecture Overview

## 1. PROJECT STRUCTURE

```
Godot-Dungeon-generator/
├── scripts/                          # Core GDScript files
│   ├── meta_cell.gd                 # Single cell definition (floor/door/blocked + connections)
│   ├── meta_room.gd                 # Room template (grid of MetaCells)
│   ├── room_rotator.gd              # Static rotation utilities (0°/90°/180°/270°)
│   ├── dungeon_generator.gd         # Main generation logic (multi-walker algorithm)
│   ├── dungeon_visualizer.gd        # Debug visualization renderer
│   └── camera_controller.gd         # Pan/zoom controls
├── resources/
│   └── rooms/                        # Room template resources (.tres files)
│       ├── cross_room_*.tres        # 4-way connection rooms (small/medium/big)
│       ├── l_corridor.tres          # L-shaped corridor
│       ├── straight_corridor.tres   # Straight hallway
│       └── t_room.tres              # T-shaped room (3 connections)
├── scenes/
│   └── test_dungeon.tscn            # Test scene with visualizer
└── addons/
    └── meta_room_editor/             # Visual editor plugin for room creation
```

### Key Components:

1. **MetaCell** (`meta_cell.gd`): Smallest unit - a single grid cell
2. **MetaRoom** (`meta_room.gd`): Room template - a grid of MetaCells
3. **RoomRotator** (`room_rotator.gd`): Static utilities for rotating rooms
4. **DungeonGenerator** (`dungeon_generator.gd`): Main generation algorithm
5. **DungeonVisualizer** (`dungeon_visualizer.gd`): Debug renderer

---

## 2. HOW ROOM PLACEMENT CURRENTLY WORKS

### 2.1 Data Structures

#### MetaCell (Single Grid Cell)
```gdscript
class_name MetaCell

enum CellType { BLOCKED = 0, FLOOR = 1, DOOR = 2 }
enum Direction { UP = 0, RIGHT = 1, BOTTOM = 2, LEFT = 3 }

@export var cell_type: CellType = FLOOR
@export var connection_up: bool = false
@export var connection_right: bool = false
@export var connection_bottom: bool = false
@export var connection_left: bool = false
@export var connection_required: bool = false  # If this connection MUST be used
```

#### MetaRoom (Room Template)
```gdscript
class_name MetaRoom

@export var width: int = 3
@export var height: int = 3
@export var cells: Array[MetaCell] = []  # Flat array (row-major: cells[y * width + x])
@export var room_name: String = "Room"

# Returns all connection points on room edges
func get_connection_points() -> Array[ConnectionPoint]
```

#### PlacedRoom (Instance in World)
```gdscript
class PlacedRoom:
    var room: MetaRoom                      # The actual room (CLONED from template)
    var position: Vector2i                  # World grid position
    var rotation: RoomRotator.Rotation      # How it's rotated (0/90/180/270)
    var original_template: MetaRoom         # Reference to original (for tracking)
```

### 2.2 Multi-Walker Algorithm

The generator uses **multiple independent walkers** that place rooms simultaneously:

```gdscript
class Walker:
    var current_room: PlacedRoom        # Where walker is now
    var rooms_placed: int = 0           # Counter
    var is_alive: bool = true           # Active status
    var max_rooms: int                  # Dies after this many
    var walker_id: int                  # Unique ID
    var path_history: Array[Vector2i]   # Trail of visited positions
    var color: Color                    # Visual color
```

### 2.3 Generation Flow

```
1. INITIALIZATION:
   ├─ Pick random starting room with connections
   ├─ CLONE it (preserve template)
   ├─ Place at origin (0, 0)
   └─ Spawn N walkers at starting room

2. MAIN LOOP (until target cell count reached):
   FOR EACH WALKER:
      ├─ Get open connections from walker's current room
      ├─ Shuffle connections (with optional compactness bias)
      ├─ FOR EACH open connection:
      │  ├─ Try up to 10 different templates/rotations
      │  ├─ Check if room can be placed (collision detection)
      │  ├─ If valid → PLACE room, CLONE it, move walker, break
      │  └─ If invalid → try next template/rotation
      │
      ├─ If placement succeeded:
      │  ├─ Increment walker.rooms_placed
      │  └─ Check if walker should die (reached max_rooms)
      │
      └─ If placement failed OR walker died:
         └─ Respawn walker at random room with open connections

3. COMPLETION:
   └─ Stop when total FLOOR cells >= target_meta_cell_count
```

### 2.4 Room Placement Logic (`_try_connect_room`)

```gdscript
func _try_connect_room(
    from_placement: PlacedRoom,
    from_connection: ConnectionPoint,  # Cell with connection_left/right/up/down = true
    to_room: MetaRoom,                  # Room to place (already rotated/cloned)
    rotation: Rotation,
    original_template: MetaRoom
) -> PlacedRoom:
    
    # 1. Find matching connection points in target room
    for to_conn in to_room.get_connection_points():
        
        # 2. Check if directions are OPPOSITE (must match for connection)
        var required_direction = opposite_direction(from_connection.direction)
        if to_conn.direction != required_direction:
            continue
        
        # 3. Calculate target position
        #    The two connection cells must OVERLAP (share world position)
        var from_world_pos = from_placement.position + Vector2i(from_connection.x, from_connection.y)
        var target_pos = from_world_pos - Vector2i(to_conn.x, to_conn.y)
        
        # 4. Check collision (allows BLOCKED cell overlap)
        if _can_place_room(to_room, target_pos):
            return PlacedRoom.new(to_room, target_pos, rotation, original_template)
    
    return null
```

### 2.5 Collision Detection (`_can_place_room`)

```gdscript
func _can_place_room(room: MetaRoom, position: Vector2i) -> bool:
    for y in range(room.height):
        for x in range(room.width):
            var cell = room.get_cell(x, y)
            if cell == null:
                continue
            
            var world_pos = position + Vector2i(x, y)
            
            # BLOCKED cells CAN overlap with other BLOCKED cells
            if cell.cell_type == CellType.BLOCKED:
                if occupied_cells.has(world_pos):
                    var existing_cell = _get_cell_at_world_pos(world_pos)
                    # Only allow if existing is also BLOCKED
                    if existing_cell == null or existing_cell.cell_type != CellType.BLOCKED:
                        return false
                continue  # BLOCKED can overlap
            
            # FLOOR/DOOR cells CANNOT overlap
            if occupied_cells.has(world_pos):
                return false
    
    return true
```

### 2.6 Key Features

- **Room Cloning**: All placed rooms are clones - templates never modified
- **BLOCKED Cell Overlap**: Rooms share edge walls for compact dungeons
- **Multi-Walker**: Multiple walkers work independently for organic layouts
- **Connection Matching**: Opposite directions must align (LEFT connects to RIGHT)
- **Rotation Attempts**: Tries all 4 rotations (0°/90°/180°/270°) per template
- **No Duplicates**: Each template can only be placed once (current system)

---

## 3. CONNECTION/DOOR LOGIC

### 3.1 Connection System

Connections are stored **per-cell** with directional flags:

```gdscript
# In MetaCell:
@export var connection_up: bool = false
@export var connection_right: bool = false
@export var connection_bottom: bool = false
@export var connection_left: bool = false
@export var connection_required: bool = false  # Per-cell requirement flag
```

### 3.2 Connection Point Detection

```gdscript
# In MetaRoom.get_connection_points():
func get_connection_points() -> Array[ConnectionPoint]:
    var connections = []
    
    for y in range(height):
        for x in range(width):
            var cell = get_cell(x, y)
            
            # Check edge cells only:
            if y == 0 and cell.connection_up:
                connections.append(ConnectionPoint.new(x, y, Direction.UP))
            
            if x == width - 1 and cell.connection_right:
                connections.append(ConnectionPoint.new(x, y, Direction.RIGHT))
            
            if y == height - 1 and cell.connection_bottom:
                connections.append(ConnectionPoint.new(x, y, Direction.BOTTOM))
            
            if x == 0 and cell.connection_left:
                connections.append(ConnectionPoint.new(x, y, Direction.LEFT))
    
    return connections
```

### 3.3 Open Connection Detection

```gdscript
func _get_open_connections(placement: PlacedRoom) -> Array[ConnectionPoint]:
    var open_connections = []
    
    for conn_point in placement.room.get_connection_points():
        # Get world position of this connection
        var conn_world_pos = placement.get_cell_world_pos(conn_point.x, conn_point.y)
        
        # Get adjacent position in connection direction
        var adjacent_pos = conn_world_pos + _get_direction_offset(conn_point.direction)
        
        # If no room at adjacent position → connection is OPEN
        if not occupied_cells.has(adjacent_pos):
            open_connections.append(conn_point)
    
    return open_connections
```

### 3.4 Connection Merging (When Rooms Overlap)

When two rooms connect, their BLOCKED cells overlap and connections merge:

```gdscript
func _merge_overlapping_cells(existing_cell: MetaCell, new_cell: MetaCell, ...) -> int:
    var potential_door = false
    var connected_direction = -1
    
    # Check for OPPOSITE-facing connections:
    
    # Horizontal: LEFT ↔ RIGHT
    if existing_cell.connection_left and new_cell.connection_right:
        existing_cell.connection_left = false
        new_cell.connection_right = false
        potential_door = true
        connected_direction = Direction.RIGHT
    
    elif existing_cell.connection_right and new_cell.connection_left:
        existing_cell.connection_right = false
        new_cell.connection_left = false
        potential_door = true
        connected_direction = Direction.LEFT
    
    # Vertical: UP ↔ BOTTOM
    if existing_cell.connection_up and new_cell.connection_bottom:
        existing_cell.connection_up = false
        new_cell.connection_bottom = false
        potential_door = true
        connected_direction = Direction.BOTTOM
    
    # Convert to DOOR if connections matched
    if potential_door:
        existing_cell.cell_type = CellType.DOOR
        new_cell.cell_type = CellType.DOOR
    else:
        # No matching connections → solid wall
        existing_cell.cell_type = CellType.BLOCKED
        new_cell.cell_type = CellType.BLOCKED
    
    return connected_direction
```

### 3.5 Connection Tracking

```gdscript
# In DungeonGenerator:
var room_connected_directions: Dictionary = {}  # PlacedRoom -> Array[Direction]

# Updated when rooms connect:
if connected_dir != -1:
    room_connected_directions[new_placement].append(connected_dir)
    room_connected_directions[existing_placement].append(opposite_direction(connected_dir))
```

### 3.6 Current Limitations

**No Required Connections Enforcement:**
- `connection_required` flag exists on MetaCell but is **not validated** during generation
- Rooms can be placed without satisfying all required connections
- A T-room with 3 connections might end up with only 1 connection used
- No mechanism to reject rooms if required connections aren't satisfied

---

## 4. WHERE TO IMPLEMENT ATOMIC MULTI-ROOM PLACEMENT

To implement atomic multi-room placement (e.g., T-Room with 3 required connections that must ALL be satisfied or entire placement is rejected), you need to modify these areas:

### 4.1 Data Model Changes

**Add to `MetaRoom`:**
```gdscript
# Add to meta_room.gd:
@export var required_connections: Array[Direction] = []  # Room-level requirements

# Example: T-Room should have required_connections = [UP, LEFT, RIGHT]
```

This already exists but is **not used** by the generator.

### 4.2 Validation Function (NEW)

**Add to `DungeonGenerator`:**
```gdscript
## Checks if all required connections for a room would be satisfied
func _validate_required_connections(
    placement: PlacedRoom,
    satisfied_connections: Array[Direction]
) -> bool:
    # If room has no requirements, it's valid
    if placement.original_template.required_connections.is_empty():
        return true
    
    # Check if all required directions are satisfied
    for required_dir in placement.original_template.required_connections:
        if not satisfied_connections.has(required_dir):
            return false  # Missing required connection
    
    return true
```

### 4.3 Modify Placement Logic

**Change `_walker_try_place_room` (lines 260-321):**

Current flow:
```
1. Get open connections
2. Try to place room at each connection
3. If valid → PLACE and commit immediately
```

New flow for atomic placement:
```
1. Get open connections
2. Try to place room at each connection
3. If valid → DON'T commit yet
4. Check which connections would be satisfied
5. Validate required connections
6. If valid → COMMIT placement
7. Else → REJECT and try next template
```

**Specific changes:**

```gdscript
# In _walker_try_place_room, replace lines 311-319:

# OLD CODE:
for rotation in rotations:
    var rotated_room = RoomRotator.rotate_room(template, rotation)
    var placement = _try_connect_room(walker.current_room, conn_point, rotated_room, rotation, template)
    
    if placement != null:
        _place_room(placement)  # ← IMMEDIATE PLACEMENT
        walker.move_to_room(placement)
        room_placed.emit(placement, walker)
        return true

# NEW CODE:
for rotation in rotations:
    var rotated_room = RoomRotator.rotate_room(template, rotation)
    var placement = _try_connect_room(walker.current_room, conn_point, rotated_room, rotation, template)
    
    if placement != null:
        # Check which connections would be satisfied
        var satisfied = _get_satisfied_connections(placement)
        
        # Validate required connections
        if _validate_required_connections(placement, satisfied):
            _place_room(placement)  # ← CONDITIONAL PLACEMENT
            walker.move_to_room(placement)
            room_placed.emit(placement, walker)
            return true
        # else: Try next rotation/template
```

### 4.4 Helper Function (NEW)

**Add to `DungeonGenerator`:**
```gdscript
## Checks which connections of a room would be satisfied if placed
## This simulates placement without actually committing
func _get_satisfied_connections(placement: PlacedRoom) -> Array[Direction]:
    var satisfied: Array[Direction] = []
    
    # Check each connection point
    for conn_point in placement.room.get_connection_points():
        var conn_world_pos = placement.get_cell_world_pos(conn_point.x, conn_point.y)
        var adjacent_pos = conn_world_pos + _get_direction_offset(conn_point.direction)
        
        # If there's a room at adjacent position → connection would be satisfied
        if occupied_cells.has(adjacent_pos):
            satisfied.append(conn_point.direction)
    
    return satisfied
```

### 4.5 Alternative: Multi-Cell Atomic Placement

For complex multi-room structures (e.g., place a T-junction with ALL 3 branches at once):

**Add to `DungeonGenerator`:**
```gdscript
## Attempts to place a multi-room structure atomically
## All rooms must be placeable or none are placed
func _try_place_multi_room(
    anchor_position: Vector2i,
    rooms: Array[MetaRoom],
    relative_positions: Array[Vector2i]
) -> Array[PlacedRoom]:
    
    var placements: Array[PlacedRoom] = []
    
    # Step 1: Validate all rooms can be placed
    for i in range(rooms.size()):
        var room = rooms[i]
        var position = anchor_position + relative_positions[i]
        
        if not _can_place_room(room, position):
            return []  # REJECT entire structure
        
        placements.append(PlacedRoom.new(room, position, Rotation.DEG_0, room))
    
    # Step 2: Validate all required connections are satisfied
    for placement in placements:
        var satisfied = _get_satisfied_connections_in_group(placement, placements)
        if not _validate_required_connections(placement, satisfied):
            return []  # REJECT entire structure
    
    # Step 3: Commit all placements atomically
    for placement in placements:
        _place_room(placement)
    
    return placements
```

### 4.6 Key Files to Modify

| File | Function | Changes Needed |
|------|----------|----------------|
| `meta_room.gd` | `MetaRoom` class | Already has `required_connections` array |
| `dungeon_generator.gd` | `_walker_try_place_room()` | Add validation before `_place_room()` |
| `dungeon_generator.gd` | `_validate_required_connections()` | **NEW FUNCTION** - validates requirements |
| `dungeon_generator.gd` | `_get_satisfied_connections()` | **NEW FUNCTION** - checks which connections would be satisfied |
| `dungeon_generator.gd` | `_try_place_multi_room()` | **OPTIONAL** - for multi-room atomic placement |

### 4.7 Testing Strategy

1. **Create test T-Room:**
   ```gdscript
   # In t_room.tres:
   required_connections = [Direction.UP, Direction.LEFT, Direction.RIGHT]
   ```

2. **Test scenarios:**
   - Place T-room in open area → should REJECT if < 3 connections available
   - Place T-room at junction → should ACCEPT if 3+ connections available
   - Rotate T-room → required connections should rotate with room

3. **Edge cases:**
   - Room with 0 required connections → should always validate
   - Room with 4 required connections (cross) → should only place at intersections
   - Walker gets stuck → should respawn (existing behavior)

### 4.8 Summary of Required Changes

**Minimal changes for atomic placement:**

1. ✅ **Data model** - `required_connections` already exists
2. ❌ **Validation function** - needs to be added
3. ❌ **Helper function** - needs `_get_satisfied_connections()`
4. ❌ **Placement logic** - modify `_walker_try_place_room()` to validate before committing
5. ❌ **Testing** - create test rooms with required connections

**Estimated complexity:** Medium (2-4 hours)

**Biggest challenge:** The current system places rooms immediately. You need to:
- Check if room CAN be placed (already done)
- Check which connections WOULD be satisfied (new)
- Validate requirements (new)
- Only then commit placement (modify existing)

This requires refactoring the placement flow to be two-phase: **simulate → validate → commit** instead of **validate → commit immediately**.

---

## 5. CURRENT ARCHITECTURE STRENGTHS

✅ **Clean separation of concerns**
- MetaCell: data model
- MetaRoom: template
- RoomRotator: pure functions
- DungeonGenerator: algorithm
- DungeonVisualizer: presentation

✅ **Resource-based templates**
- Easy to create/edit in Godot editor
- Visual editor plugin available
- Templates are preserved (all placements are clones)

✅ **Multi-walker algorithm**
- Creates organic, interconnected dungeons
- Natural loop formation
- Walkers can spawn/die dynamically

✅ **Smart collision detection**
- BLOCKED cells can overlap (shared walls)
- Connection merging creates doors
- Fast Dictionary-based lookup

✅ **Visualization tools**
- Real-time walker tracking
- Path history visualization
- Step-by-step mode for debugging

---

## 6. CURRENT ARCHITECTURE WEAKNESSES

❌ **No required connection enforcement**
- `connection_required` flag exists but is unused
- Rooms can be placed without satisfying requirements
- T-rooms can end up with only 1 connection

❌ **No duplicate prevention**
- Comment says "each template can only be placed once"
- But no actual enforcement in code
- Could be intentional or not implemented yet

❌ **No pathfinding validation**
- Rooms might not be reachable
- No guarantee of connected dungeon
- Could create isolated areas

❌ **Walker spawning is random**
- No preference for rooms with unsatisfied requirements
- Could leave some rooms under-connected

---

## 7. IMPLEMENTATION ROADMAP

### Phase 1: Required Connection Enforcement (Current Gap)
1. Implement `_validate_required_connections()`
2. Implement `_get_satisfied_connections()`
3. Modify `_walker_try_place_room()` to validate before placing
4. Test with T-rooms

### Phase 2: Multi-Room Atomic Placement (Your Request)
1. Implement `_try_place_multi_room()`
2. Define multi-room structures (e.g., T-junction with 3 rooms)
3. Add walker support for multi-room placement
4. Test with complex structures

### Phase 3: Advanced Features (Optional)
1. Pathfinding validation
2. Smarter walker spawning (prefer rooms with unsatisfied connections)
3. Duplicate detection/prevention (if desired)
4. Room type/tag system

---

## 8. CODE LOCATIONS QUICK REFERENCE

### For Atomic Placement Implementation:

```
meta_room.gd
├─ Line 19: required_connections already exists (unused)
└─ Add: validation methods

dungeon_generator.gd
├─ Lines 260-321: _walker_try_place_room()
│  └─ MODIFY: Add validation before _place_room()
├─ Lines 402-432: _try_connect_room()
│  └─ OK: No changes needed
├─ Lines 434-460: _can_place_room()
│  └─ OK: No changes needed
├─ Lines 473-553: _place_room() and _merge_overlapping_cells()
│  └─ OK: No changes needed
└─ ADD NEW:
   ├─ _validate_required_connections()
   ├─ _get_satisfied_connections()
   └─ _try_place_multi_room() (optional)
```

This architecture overview should give you everything you need to implement atomic multi-room placement with required connection validation!
