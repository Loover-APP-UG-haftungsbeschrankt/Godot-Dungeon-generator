# BUG REPORT: Connection Room System

## Summary
**The bug is in `_can_fulfill_required_connections()` in `dungeon_generator.gd`.**

The validation logic checks if a room exists adjacent to a required connection, but **it does NOT verify that the adjacent cell has a matching connection pointing back**.

## The Problem

When validating if a connection room (T-room, L-room) can be placed, the code checks:
1. ✅ A room exists at the adjacent position
2. ✅ That room is not a connection room
3. ❌ **MISSING**: The adjacent cell has a connection in the opposite direction

## Why This Causes the Symptoms

### T-rooms not appearing
- T-rooms have 3 required connections
- When trying to place a T-room, it connects via one connection
- The other 2 connections must be pre-satisfied
- For those 2 connections, the validation checks if normal rooms exist adjacent
- **BUT** most normal rooms don't have connections at those exact positions!
- So validation almost always fails → T-rooms rarely placed

### L-rooms appearing but connections not fulfilled
- L-rooms have 2 required connections
- Occasionally, normal rooms exist at the right adjacent positions
- Validation passes (room exists + not a connection room)
- L-room gets placed
- **BUT** those adjacent rooms don't have matching connections!
- Result: L-room is placed but its connections point to walls/floors without matching connections

## Code Location

File: `scripts/dungeon_generator.gd`
Function: `_can_fulfill_required_connections()`
Lines: 430-492

The problematic section (lines 466-488):
```gdscript
# Required connections MUST have a normal room already placed at the adjacent position
if not occupied_cells.has(adjacent_pos):
    # No room exists - required connection cannot be fulfilled
    if debug_connection_rooms and is_debug_room:
        print("    ✗ REJECTED: No room at adjacent position")
    return false

var existing_placement = occupied_cells[adjacent_pos]

if debug_connection_rooms and is_debug_room:
    print("    Room found: ", existing_placement.room.room_name, " is_connection=", existing_placement.room.is_connection_room())

# Check if the existing room is a connection room
# Connection rooms cannot satisfy required connections
if existing_placement.room.is_connection_room():
    if debug_connection_rooms and is_debug_room:
        print("    ✗ REJECTED: Existing room is a connection room")
    return false

# Normal room exists, which is fine - the connection will be satisfied
if debug_connection_rooms and is_debug_room:
    print("    ✓ OK: Normal room found")
# Continue checking other required connections
```

## What's Missing

After finding the existing room at `adjacent_pos`, the code needs to:
1. Get the cell at `adjacent_pos` from the existing room
2. Check if that cell has a connection in the **opposite direction**
3. Only accept if the matching connection exists

## Example Scenario

```
Scenario: T-room trying to place
- T-room has required LEFT connection at cell (0,1) 
- This is a BLOCKED cell with connection_left=true
- Adjacent position (to the left) is (-1,1)

Current validation:
1. Check occupied_cells.has((-1,1)) → TRUE (room exists)
2. Check is_connection_room() → FALSE (it's a normal room)
3. Validation PASSES ✓

Reality:
- The cell at (-1,1) is a FLOOR cell with NO connections
- Or it's a BLOCKED cell with connections in other directions
- The T-room's LEFT connection points to a cell that can't connect back!
- No door is created, connection is unfulfilled

Should be:
1. Check occupied_cells.has((-1,1)) → TRUE
2. Check is_connection_room() → FALSE
3. Get the cell at (-1,1) from the existing room
4. Check if that cell has connection_right=true (opposite of LEFT)
5. Only if TRUE, validation passes
```

## The Fix

Add a check to verify the adjacent cell has a matching connection:

```gdscript
var existing_placement = occupied_cells[adjacent_pos]

# Check if the existing room is a connection room
if existing_placement.room.is_connection_room():
    return false

# NEW: Check if the adjacent cell has a matching connection
var adjacent_cell = _get_cell_at_world_pos(existing_placement, adjacent_pos)
if adjacent_cell == null:
    return false

# Check if the adjacent cell has a connection pointing back
var required_opposite_direction = MetaCell.opposite_direction(conn_point.direction)
if not adjacent_cell.has_connection(required_opposite_direction):
    # Adjacent cell exists but doesn't have matching connection
    return false

# Normal room with matching connection exists - OK
```

## Verification

To verify this is the bug:
1. Enable debug logging in `_can_fulfill_required_connections()` (set line 434 to `true`)
2. Generate a dungeon
3. Look for messages like "Room found" followed by "✓ OK: Normal room found"
4. Check if those "OK" validations actually have matching connections
5. You'll find many cases where normal rooms are accepted but their cells don't have matching connections

## Impact

This bug makes connection rooms (L, T, I shapes) nearly impossible to place correctly:
- They either don't appear (validation correctly fails)
- Or they appear but connections are unfulfilled (validation incorrectly passes)

The system needs to validate that adjacent cells actually have compatible connections, not just that rooms exist.
