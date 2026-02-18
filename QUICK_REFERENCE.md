# Quick Reference - Atomic Multi-Room Placement

## TL;DR

**Current State:**
- ✅ Multi-walker algorithm places rooms one at a time
- ✅ Rooms have `required_connections` array (but it's NOT validated)
- ❌ T-rooms can be placed with only 1 connection used (should require all 3)
- ❌ No atomic placement (can't reject a room if requirements not met)

**What You Need:**
- Validate that all `required_connections` are satisfied before committing placement
- Reject room placement if ANY required connection is missing

---

## Key Data Structures

```gdscript
# MetaCell - Single grid cell
class MetaCell:
    cell_type: CellType           # BLOCKED/FLOOR/DOOR
    connection_up: bool           # Can connect upward?
    connection_right: bool
    connection_bottom: bool
    connection_left: bool
    connection_required: bool     # Is this connection mandatory?

# MetaRoom - Room template
class MetaRoom:
    width: int, height: int
    cells: Array[MetaCell]
    required_connections: Array[Direction]  # ← EXISTS BUT UNUSED!
    # Example: T-room should have [UP, LEFT, RIGHT]

# PlacedRoom - Instance in world
class PlacedRoom:
    room: MetaRoom                # The actual room (CLONED)
    position: Vector2i            # World grid position
    rotation: Rotation            # 0/90/180/270 degrees
    original_template: MetaRoom   # Reference to template
```

---

## Current Placement Flow (Lines 260-321)

```
_walker_try_place_room(walker):
    ├─ Get open connections from walker's room
    ├─ FOR EACH open connection:
    │  ├─ Try random template
    │  ├─ FOR EACH rotation (0/90/180/270):
    │  │  ├─ Rotate room
    │  │  ├─ _try_connect_room() → Returns PlacedRoom or null
    │  │  └─ If not null:
    │  │     ├─ _place_room(placement)      ← IMMEDIATE COMMIT
    │  │     ├─ walker.move_to_room()
    │  │     └─ return true
    │  └─ Try next template
    └─ return false (couldn't place)
```

**Problem:** Placement happens immediately without checking if `required_connections` are satisfied.

---

## What You Need to Add

### 1. Validation Function (NEW)

```gdscript
## Add to dungeon_generator.gd

## Checks if all required connections would be satisfied
func _validate_required_connections(
    placement: PlacedRoom,
    satisfied_connections: Array[MetaCell.Direction]
) -> bool:
    # No requirements? Always valid
    if placement.original_template.required_connections.is_empty():
        return true
    
    # Check each required direction
    for required_dir in placement.original_template.required_connections:
        if not satisfied_connections.has(required_dir):
            return false  # Missing required connection
    
    return true
```

### 2. Helper Function (NEW)

```gdscript
## Add to dungeon_generator.gd

## Checks which connections would be satisfied if room is placed
## (Simulates without committing)
func _get_satisfied_connections(placement: PlacedRoom) -> Array[MetaCell.Direction]:
    var satisfied: Array[MetaCell.Direction] = []
    
    # Check each connection point
    for conn_point in placement.room.get_connection_points():
        var conn_world_pos = placement.get_cell_world_pos(conn_point.x, conn_point.y)
        var adjacent_pos = conn_world_pos + _get_direction_offset(conn_point.direction)
        
        # Is there a room at adjacent position?
        if occupied_cells.has(adjacent_pos):
            satisfied.append(conn_point.direction)
    
    return satisfied
```

### 3. Modify Placement Logic (CHANGE EXISTING)

```gdscript
# In _walker_try_place_room(), around line 311:

# OLD CODE:
for rotation in rotations:
    var rotated_room = RoomRotator.rotate_room(template, rotation)
    var placement = _try_connect_room(walker.current_room, conn_point, rotated_room, rotation, template)
    
    if placement != null:
        _place_room(placement)  # ← IMMEDIATE
        walker.move_to_room(placement)
        room_placed.emit(placement, walker)
        return true

# NEW CODE:
for rotation in rotations:
    var rotated_room = RoomRotator.rotate_room(template, rotation)
    var placement = _try_connect_room(walker.current_room, conn_point, rotated_room, rotation, template)
    
    if placement != null:
        # NEW: Check which connections would be satisfied
        var satisfied = _get_satisfied_connections(placement)
        
        # NEW: Validate required connections
        if _validate_required_connections(placement, satisfied):
            _place_room(placement)  # ← CONDITIONAL
            walker.move_to_room(placement)
            room_placed.emit(placement, walker)
            return true
        # else: Try next rotation/template (room is rejected)
```

---

## File Locations

```
dungeon_generator.gd
├─ Line 260: _walker_try_place_room()
│  └─ Modify placement logic (around line 311)
│
├─ ADD NEW FUNCTIONS:
│  ├─ _validate_required_connections()
│  └─ _get_satisfied_connections()
│
└─ No changes needed:
   ├─ _try_connect_room() (lines 402-432)
   ├─ _can_place_room() (lines 434-460)
   └─ _place_room() (lines 473-510)
```

---

## Testing

1. **Create test T-Room:**
   - Edit `resources/rooms/t_room.tres`
   - Set `required_connections = [UP, LEFT, RIGHT]` (if not already set)

2. **Expected behavior:**
   - T-room at open area (< 3 connections) → REJECTED
   - T-room at junction (3+ connections) → ACCEPTED
   - T-room rotated → required connections rotate with it

3. **Test with visualizer:**
   - Run test scene (F5)
   - Watch walkers try to place T-rooms
   - They should only succeed at 3+ connection junctions

---

## Key Concepts

### Connection Matching
```
Room A connects RIGHT → Must find Room B with LEFT connection
Opposite directions required:
- UP ↔ BOTTOM
- LEFT ↔ RIGHT
```

### BLOCKED Cell Overlap
```
Room A    Room B    Result
■ ■ ■     ■ ■ ■     ■ ■ ■ ■ ■
■·→[■]  + [■]←·■  = ■·→←·■
■ ■ ■     ■ ■ ■     ■ ■ ■ ■ ■

[■] = Shared blocked cell (overlaps)
The two ← → connections merge to create a door
```

### Required Connections
```
T-Room has 3 connections:
  UP
  ↑
LEFT ← ● → RIGHT

required_connections = [UP, LEFT, RIGHT]

For placement to be valid, ALL 3 must connect to existing rooms:
✅ Valid:   Junction with 3+ adjacent rooms
❌ Invalid: Dead end with only 1 adjacent room
```

---

## Advanced: Multi-Room Atomic Placement (Optional)

For placing multiple rooms at once (e.g., T-junction with all 3 branches):

```gdscript
func _try_place_multi_room(
    anchor_position: Vector2i,
    rooms: Array[MetaRoom],
    relative_positions: Array[Vector2i]
) -> Array[PlacedRoom]:
    var placements: Array[PlacedRoom] = []
    
    # Step 1: Check ALL rooms can be placed
    for i in range(rooms.size()):
        if not _can_place_room(rooms[i], anchor_position + relative_positions[i]):
            return []  # REJECT entire structure
        placements.append(PlacedRoom.new(...))
    
    # Step 2: Validate ALL required connections
    for placement in placements:
        var satisfied = _get_satisfied_connections_in_group(placement, placements)
        if not _validate_required_connections(placement, satisfied):
            return []  # REJECT entire structure
    
    # Step 3: Commit ALL placements atomically
    for placement in placements:
        _place_room(placement)
    
    return placements
```

---

## Debugging

**Print statements to add:**

```gdscript
# In _walker_try_place_room():
print("Trying to place: ", template.room_name)
print("Required connections: ", template.required_connections)

# After _get_satisfied_connections():
print("Satisfied connections: ", satisfied)

# After _validate_required_connections():
print("Validation result: ", is_valid)
```

**Visualizer hotkeys:**
- `R` - Regenerate with same seed
- `S` - Generate with new seed
- `V` - Toggle step-by-step mode (watch placement in slow motion)
- `P` - Toggle path visualization
- `N` - Toggle step numbers

---

## Estimated Implementation Time

- Add validation functions: **30 min**
- Modify placement logic: **15 min**
- Testing and debugging: **1-2 hours**
- **Total: 2-3 hours** for basic required connection validation

For multi-room atomic placement: **+2-4 hours**
