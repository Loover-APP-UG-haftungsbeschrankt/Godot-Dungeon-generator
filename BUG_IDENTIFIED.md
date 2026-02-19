## EXACT BUG IDENTIFICATION

After thorough analysis, I've identified the bug in the connection room system.

## THE BUG 🐛

**Location**: `scripts/dungeon_generator.gd`, function `_can_fulfill_required_connections()`, lines 466-488

**Problem**: The validation checks if a normal room exists adjacent to a required connection, but **does NOT verify that the adjacent cell has a matching connection pointing back**.

## Why This is the Bug

### What the Code Currently Does:

```gdscript
# Line 466-482 in _can_fulfill_required_connections()
if not occupied_cells.has(adjacent_pos):
    return false  # No room exists

var existing_placement = occupied_cells[adjacent_pos]

if existing_placement.room.is_connection_room():
    return false  # Can't connect to another connection room

# Line 485-486: Accept!
if debug_connection_rooms and is_debug_room:
    print("    ✓ OK: Normal room found")
```

### The Missing Check:

The code accepts the placement as long as:
1. ✅ A room exists at the adjacent position
2. ✅ That room is not a connection room

**But it never checks if the adjacent cell actually has a connection pointing back!**

### What Should Happen:

```gdscript
# After line 482, before accepting:

# Get the actual cell at the adjacent position
var adjacent_cell = _get_cell_at_world_pos(existing_placement, adjacent_pos)
if adjacent_cell == null:
    return false

# Check if that cell has a connection in the opposite direction
var required_opposite_dir = MetaCell.opposite_direction(conn_point.direction)
if not adjacent_cell.has_connection(required_opposite_dir):
    # Adjacent cell exists but can't connect!
    return false
```

## Concrete Example

### Scenario: Placing a T-Room

**T-Room structure** (5x4):
- Cell (0,1): BLOCKED with LEFT connection (required)
- Cell (4,1): BLOCKED with RIGHT connection (required)
- Cell (2,3): BLOCKED with BOTTOM connection (required)

**Placement attempt**:
1. Connect T-room via BOTTOM connection to existing room below
2. Validation checks LEFT and RIGHT required connections

**For LEFT connection at (0,1)**:
- World position: (10,11) [assuming T-room placed at 10,10]
- Adjacent position (LEFT): (9,11)
- Current validation:
  - ✅ Room exists at (9,11)?  YES
  - ✅ Is it a normal room? YES
  - ✅ **Validation PASSES**
  
**Reality at (9,11)**:
- Cell type: FLOOR
- Connections: `connection_up=true`, all others=`false`
- **Has RIGHT connection? NO!**
- Result: T-room's LEFT connection points to a FLOOR cell without matching connection
- **No door is created**, connection unfulfilled!

## Why This Causes the Symptoms

### Symptom 1: T-rooms not appearing

T-rooms have **3 required connections**. To place a T-room:
- Connect via 1 connection (automatic)
- Other 2 connections must be pre-satisfied
- Need 2 adjacent normal rooms

**Why they don't appear:**
- Finding 2 adjacent rooms is already rare
- Even when found, those rooms' cells rarely have matching connections
- With proper validation (checking matching connections), T-rooms would be rejected
- Current buggy validation accepts them, but then they have unfulfilled connections
- This might cause downstream issues that prevent them from appearing in final dungeon

### Symptom 2: L-rooms don't have all connections fulfilled

L-rooms have **2 required connections**. To place an L-room:
- Connect via 1 connection (automatic)
- Other 1 connection must be pre-satisfied
- Need 1 adjacent normal room

**Why connections aren't fulfilled:**
- Finding 1 adjacent room is more common than 2
- Current validation accepts as long as room exists (doesn't check matching connection)
- L-room gets placed
- But the adjacent cell doesn't have a matching connection
- Result: L-room is placed but its required connection points to a wall/floor without matching connection
- **Connection is unfulfilled!**

## The Fix

Add this check in `_can_fulfill_required_connections()` after line 482:

```gdscript
var existing_placement = occupied_cells[adjacent_pos]

if debug_connection_rooms and is_debug_room:
    print("    Room found: ", existing_placement.room.room_name, " is_connection=", existing_placement.room.is_connection_room())

# Check if the existing room is a connection room
# Connection rooms cannot satisfy required connections
if existing_placement.room.is_connection_room():
    if debug_connection_rooms and is_debug_room:
        print("    ✗ REJECTED: Existing room is a connection room")
    return false

# **NEW CHECK**: Verify the adjacent cell has a matching connection
var adjacent_cell = _get_cell_at_world_pos(existing_placement, adjacent_pos)
if adjacent_cell == null:
    if debug_connection_rooms and is_debug_room:
        print("    ✗ REJECTED: No cell at adjacent position")
    return false

# Check if the adjacent cell has a connection pointing back toward this room
var required_opposite_direction = MetaCell.opposite_direction(conn_point.direction)
if not adjacent_cell.has_connection(required_opposite_direction):
    if debug_connection_rooms and is_debug_room:
        print("    ✗ REJECTED: Adjacent cell has no matching connection")
        print("       Required: ", required_opposite_direction, " but cell has:")
        print("       UP=", adjacent_cell.connection_up, " RIGHT=", adjacent_cell.connection_right,
              " BOTTOM=", adjacent_cell.connection_bottom, " LEFT=", adjacent_cell.connection_left)
    return false

# Normal room with matching connection exists - this is what we want!
if debug_connection_rooms and is_debug_room:
    print("    ✓ OK: Normal room with matching connection found")
```

## Verification Steps

To verify this is the bug:

1. Add debug logging to see what's being validated
2. Generate a dungeon
3. Look for L-rooms that were placed
4. Check their required connections
5. Verify the adjacent cells **don't** have matching connections

This will confirm that the validation is incorrectly accepting placements where connections don't match.

## Summary

**The bug**: `_can_fulfill_required_connections()` accepts placements when a normal room exists adjacent to a required connection, without verifying that the adjacent cell has a connection pointing back.

**The fix**: Add a check to verify the adjacent cell has a connection in the opposite direction before accepting the placement.

**Impact**: Without this fix, connection rooms are either rejected (no adjacent rooms) or placed with unfulfilled connections (adjacent rooms exist but can't connect).
