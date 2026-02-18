# Visual Guide - Room Placement & Connection System

## Room Structure

### MetaCell (Single Grid Cell)
```
┌─────────────────────┐
│     MetaCell        │
├─────────────────────┤
│ cell_type: FLOOR    │
│ connection_up: T    │  ← Can connect upward
│ connection_right: F │
│ connection_bottom: F│
│ connection_left: F  │
│ connection_req: F   │  ← Is this connection required?
└─────────────────────┘
```

### MetaRoom (Grid of Cells)
```
T-Room (5x4 grid):

     0   1   2   3   4
   ┌───┬───┬───┬───┬───┐
 0 │ ■ │ ■ │ ■ │ ■ │ ■ │  ■ = BLOCKED
   ├───┼───┼───┼───┼───┤
 1 │ ■ │ · │ · │ · │ ■ │  · = FLOOR
   ├───┼───┼───┼───┼───┤  ↑ = connection_up
 2 │ ■ │ ■ │ · │ ■ │ ■ │  ← = connection_left
   ├───┼───┼───┼───┼───┤  → = connection_right
 3 │ ■ │ ■ │ ■ │ ■ │ ■ │  ↓ = connection_bottom
   └───┴───┴───┴───┴───┘
      ↑           ↑
   (0,1)←       (4,1)→
      
Connection Points:
- (0,1) LEFT:  connection_left = true
- (4,1) RIGHT: connection_right = true  
- (2,0) UP:    connection_up = true

Required: [UP, LEFT, RIGHT]  ← Must ALL be connected
```

## Connection Matching

### Opposite Directions Must Match
```
Room A wants to connect RIGHT (→)
Room B must have connection LEFT (←)

   Room A              Room B
┌──────────┐       ┌──────────┐
│   ■ ■ ■  │       │  ■ ■ ■   │
│   ■ · →[■]   +   [■]← · ■   │ = VALID
│   ■ ■ ■  │       │  ■ ■ ■   │
└──────────┘       └──────────┘
        [■] = Shared blocked cell

Direction pairs:
UP ↔ BOTTOM
LEFT ↔ RIGHT
```

### Invalid Connection
```
Room A wants RIGHT (→)
Room B has no LEFT (×)

   Room A              Room B
┌──────────┐       ┌──────────┐
│   ■ ■ ■  │       │  ■ ■ ■   │
│   ■ · →[■]   +   [■]× · ■   │ = INVALID
│   ■ ■ ■  │       │  ■ ■ ■   │
└──────────┘       └──────────┘
                      No connection_left

Result: _try_connect_room() returns null
```

## Room Overlap System

### BLOCKED Cells Can Overlap
```
Before:
   Room A (3x3)         Room B (3x3)
   
   ■ ■ ■               ■ ■ ■
   ■ · →               ← · ■
   ■ ■ ■               ■ ■ ■

After placing Room B at (3, 0):
   
   ■ ■ ■ ■ ■     (5 cells wide, not 6)
   ■ · → ← · ■   → ← merge to create DOOR
   ■ ■ ■ ■ ■

The middle column is SHARED:
- Room A's right edge (x=2)
- Room B's left edge (x=0)
- Both are at world position (2, y)
```

### Connection Merging
```
When BLOCKED cells overlap with opposite connections:

existing_cell.connection_left = true
new_cell.connection_right = true

Result:
1. Remove both connections (prevent passthrough)
2. Convert both cells to DOOR type
3. This creates a door between rooms

existing_cell.connection_left = false   ← Removed
new_cell.connection_right = false        ← Removed
existing_cell.cell_type = DOOR          ← Changed
new_cell.cell_type = DOOR               ← Changed
```

## Current vs. Required Placement

### Current System (IMMEDIATE PLACEMENT)
```
_walker_try_place_room():
  ├─ Get open connections
  ├─ Try template
  │  ├─ Try rotation
  │  │  ├─ _try_connect_room() → placement or null
  │  │  └─ If not null:
  │  │     └─ _place_room(placement)  ← IMMEDIATE COMMIT
  │  │        └─ Add to placed_rooms[]
  │  │           └─ Mark cells as occupied
  │  │              └─ CANNOT UNDO
  │
  └─ Required connections NOT checked ❌
```

### Required System (ATOMIC PLACEMENT)
```
_walker_try_place_room():
  ├─ Get open connections
  ├─ Try template
  │  ├─ Try rotation
  │  │  ├─ _try_connect_room() → placement or null
  │  │  └─ If not null:
  │  │     ├─ _get_satisfied_connections(placement) ← NEW
  │  │     │  └─ Check which connections would connect
  │  │     │
  │  │     ├─ _validate_required_connections()     ← NEW
  │  │     │  └─ Are ALL required connections satisfied?
  │  │     │
  │  │     └─ If valid:
  │  │        └─ _place_room(placement)  ← CONDITIONAL COMMIT
  │  │           └─ Add to placed_rooms[]
  │  │        else:
  │  │           └─ Reject, try next rotation
  │
  └─ Required connections ARE checked ✅
```

## Example: T-Room Placement

### Scenario 1: Invalid Placement (< 3 connections)
```
Existing dungeon:
   ┌───┬───┬───┐
   │ · │ · │ · │  Room A
   └───┴───┴───┘

Walker tries to place T-Room:
       ↑
     ┌─■─┐
  ←■ │ · │ ■→
     └─■─┘
       ↓
Required: [UP, LEFT, RIGHT]

Position: Below Room A

Satisfied connections:
- UP: ✅ (connects to Room A)
- LEFT: ❌ (no room)
- RIGHT: ❌ (no room)

Result: _validate_required_connections() returns FALSE
T-Room placement REJECTED ❌
Walker tries next template/rotation
```

### Scenario 2: Valid Placement (3+ connections)
```
Existing dungeon:
         Room B
         ┌───┐
   Room A│ · │Room C
   ┌───┬─┴─┬─┴───┐
   │ · │ · │ · · │
   └───┴───┴─────┘

Walker tries to place T-Room at junction:
       ↑
     ┌─■─┐
  ←■ │ · │ ■→
     └─■─┘
       ↓
Required: [UP, LEFT, RIGHT]

Satisfied connections:
- UP: ✅ (connects to Room B)
- LEFT: ✅ (connects to Room A)
- RIGHT: ✅ (connects to Room C)

Result: _validate_required_connections() returns TRUE
T-Room placement ACCEPTED ✅
Walker moves to T-Room
```

## Walker Behavior

### Walker States
```
┌─────────────┐
│   ALIVE     │ ← Actively placing rooms
├─────────────┤
│ current_room│
│ rooms_placed│
│ max_rooms   │
│ path_history│
└─────────────┘
      │
      ├─ Placement success → rooms_placed++
      ├─ rooms_placed >= max_rooms → DIE
      └─ Placement failed → DIE

┌─────────────┐
│    DEAD     │ ← Triggers respawn
└─────────────┘
      │
      ├─ 50%: Respawn at current position (if has open connections)
      └─ 50%: Respawn at random room with open connections
            └─ Prefer rooms with unsatisfied required connections (70%)

┌─────────────┐
│  RESPAWNED  │ ← Back to ALIVE
├─────────────┤
│ rooms_placed│ = 0
│ is_alive    │ = true
└─────────────┘
```

### Walker Path Example
```
Start → Room1 → Room2 → Room3 (teleport) → Room5 → Room6
  0       1       2        3                  4       5

Path visualization:
- Solid lines: Normal moves (adjacent rooms)
- Dotted lines: Teleports (non-adjacent)
- Numbers: Step markers
- Color: Walker-specific
```

## Data Flow

### Placement Pipeline
```
Template Resources (*.tres)
        ↓
  Load templates[]
        ↓
  Generate() starts
        ↓
  Clone first room  ← CLONING
        ↓
  Place at origin
        ↓
  Spawn walkers
        ↓
┌───────────────────────┐
│  Walker attempts      │
│  to place room        │
└───────────────────────┘
        ↓
  Pick random template
        ↓
  RoomRotator.rotate_room() ← CLONING
        ↓
  _try_connect_room()
        ↓
  _can_place_room()?
        ↓
    ┌───┴───┐
    │ Valid? │
    └───┬───┘
        ↓
    ┌───────────────────────┐
    │ NEW: Validate         │
    │ required connections  │
    └───┬───────────────────┘
        │
    ┌───┴───┐
    │Valid? │
    └───┬───┘
        ↓
  _place_room()
        ↓
  Update occupied_cells{}
        ↓
  Merge overlapping cells
        ↓
  Track connections
        ↓
  Walker moves
```

## Algorithm Comparison

### Single-Walker (Old)
```
Start
  ↓
Place room
  ↓
Try next room ─┐
  ↓            │
Success? ──────┤
  │            │
  └──> Continue until N rooms
  
Result: Linear paths, many dead ends
```

### Multi-Walker (Current)
```
Start
  ↓
Spawn 3 walkers
  ├─ Walker 0 places room
  ├─ Walker 1 places room
  └─ Walker 2 places room
  ↓
Walkers die/respawn
  ├─ New walker at random junction
  ├─ New walker at unsatisfied connection
  └─ New walker at current position
  ↓
Continue until N cells

Result: Organic layouts, loops, interconnected
```

## Memory Layout

### occupied_cells Dictionary
```
Dictionary {
  Vector2i(0, 0): PlacedRoom_1,
  Vector2i(1, 0): PlacedRoom_1,
  Vector2i(2, 0): PlacedRoom_1,
  Vector2i(3, 0): PlacedRoom_2,  ← Overlapped cell
  Vector2i(4, 0): PlacedRoom_2,
  ...
}

Fast O(1) lookup: occupied_cells.has(world_pos)
```

### placed_rooms Array
```
Array [
  PlacedRoom {
    room: MetaRoom (clone),
    position: Vector2i(0, 0),
    rotation: DEG_0,
    original_template: MetaRoom (template ref)
  },
  PlacedRoom { ... },
  ...
]

Iteration: for placement in placed_rooms
```

## Rotation Transform

### 90° Clockwise
```
Original (3x3):        Rotated 90° (3x3):
  0 1 2                  0 1 2
0 A B C                0 G D A
1 D E F      →         1 H E B
2 G H I                2 I F C

Position transform:
(x, y) → (y, width-1-x)
(0, 0) → (0, 2) = A → A
(1, 0) → (0, 1) = B → D
(2, 0) → (0, 0) = C → G

Connection transform:
UP → RIGHT
RIGHT → BOTTOM
BOTTOM → LEFT
LEFT → UP
```

## Summary

**Key Points:**

1. **Rooms are grids of cells** with connection flags
2. **Connection matching**: Opposite directions must align
3. **BLOCKED overlap**: Rooms share edge walls (compact dungeons)
4. **Multi-walker**: Multiple growth points for organic layouts
5. **Cloning**: Templates preserved, placements are modified
6. **Required connections**: Currently exist but NOT validated ❌
7. **Atomic placement**: Need to add validation before commit ✅

**Implementation Gap:**

```gdscript
// Current:
if can_place:
    place_room()  // ← No validation

// Required:
if can_place:
    satisfied = get_satisfied_connections()
    if validate_required(satisfied):
        place_room()  // ← With validation
    else:
        reject()  // ← Try next
```

That's the core of what you need to implement! 🎯
