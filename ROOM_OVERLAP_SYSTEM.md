# Room Overlap System Documentation

## Overview

The dungeon generator now supports overlapping of blocked edge cells when connecting rooms. This creates more compact dungeons with shared walls between adjacent rooms.

## Problem Solved

Previously, when two 3x3 rooms were connected horizontally, they would be placed 6 cells apart (3 + 3). With the new system where outer cells are always blocked, this created unnecessary gaps.

Now, the blocked edge cells overlap, resulting in:
- **Two 3x3 rooms horizontally** = 5 cells wide (3 + 3 - 1 overlap)
- **Two 3x3 rooms vertically** = 5 cells tall (3 + 3 - 1 overlap)

## How It Works

### 1. Connection Point Alignment

When connecting rooms, the connection cells now align at the **same world position** instead of being offset by one cell:

```
Before (no overlap):
Room A    Gap    Room B
■ ■ ■     ■      ■ ■ ■
■·→■            ■←·■
■ ■ ■            ■ ■ ■
(3 cells) (1)   (3 cells) = 7 cells total

After (with overlap):
Room A overlaps Room B
■ ■ ■ ■ ■
■·→←·■
■ ■ ■ ■ ■
(5 cells total - shared middle column)
```

### 2. Blocked Cell Overlap Rules

**Allowed Overlaps:**
- BLOCKED cells can overlap with other BLOCKED cells ✓
- This allows rooms to share their edge walls

**Not Allowed:**
- BLOCKED cells cannot overlap with FLOOR or DOOR cells ✗
- FLOOR cells cannot overlap with anything ✗
- DOOR cells cannot overlap with anything ✗

### 3. Connection Merging

When two blocked cells overlap and both have connections pointing at each other, those connections are removed:

```
Room A has blocked cell with RIGHT connection
Room B has blocked cell with LEFT connection
When overlapped: Both connections removed → Solid wall

Example:
Room A: ■·→[■]  (connection pointing RIGHT)
Room B:    [■]←·■  (connection pointing LEFT)
Result: ■·■·■  (no connections, solid wall)
```

This applies to both horizontal (LEFT-RIGHT) and vertical (UP-DOWN) connections.

## Implementation Details

### Modified Functions

#### `_can_place_room(room: MetaRoom, position: Vector2i) -> bool`
- Checks each cell of the new room
- For BLOCKED cells: Allows overlap only if existing cell is also BLOCKED
- For non-BLOCKED cells: No overlap allowed (returns false)

#### `_try_connect_room(...) -> PlacedRoom`
- Calculates room position to align connection cells at same world position
- Formula: `target_pos = from_world_pos - Vector2i(to_conn.x, to_conn.y)`
- No longer adds direction offset (which created the gap)

#### `_place_room(placement: PlacedRoom) -> void`
- Iterates through all cells in the new room
- Detects overlapping BLOCKED cells
- Calls `_merge_overlapping_cells()` for overlaps
- Only adds non-BLOCKED cells to `occupied_cells` dictionary

#### `_merge_overlapping_cells(existing_cell: MetaCell, new_cell: MetaCell) -> void`
- Checks all four possible opposite-facing connection pairs:
  - LEFT ↔ RIGHT
  - RIGHT ↔ LEFT
  - UP ↔ DOWN
  - DOWN ↔ UP
- Removes both connections if they point at each other
- Ensures both cells remain BLOCKED type

#### `_get_cell_at_world_pos(placement: PlacedRoom, world_pos: Vector2i) -> MetaCell`
- Helper function to retrieve a cell from a placed room at a world position
- Converts world position to local room coordinates
- Returns null if position is out of room bounds

## Example Scenarios

### Scenario 1: L-Corridor Connecting to Straight Corridor

```
L-Corridor (3x3):          Straight Corridor (3x3):
■ ■ ■                      ■ ■ ■
■·→[■]                     ■ ↑ ■
■ ■ ■                      ■ ■ ■

When connected horizontally:
■ ■ ■ ■ ■
■·→↑■
■ ■ ■ ■ ■
(5 cells wide, not 6)
```

### Scenario 2: T-Junction Connecting to Cross Room

```
T-Junction (3x3):          Cross Room (3x3):
■ ↑ ■                      ■ ↑ ■
■·→[■]                     [■]←·→■
■ ■ ■                      ■ ↓ ■

When connected:
The blocked cell with RIGHT connection meets blocked cell with LEFT connection
→ Both connections removed → Solid wall between them
```

### Scenario 3: Multiple Room Chain

```
Room A → Room B → Room C
■ ■ ■   ■ ■ ■   ■ ■ ■
■·→[■←·→]■←·■
■ ■ ■   ■ ■ ■   ■ ■ ■

Total width: 7 cells (3 + 2 + 2)
Instead of: 9 cells (3 + 3 + 3)
Saved: 2 cells through overlaps
```

## Benefits

1. **Compact Dungeons**: Rooms are closer together, creating tighter layouts
2. **Realistic Walls**: Shared walls between rooms are natural
3. **Space Efficiency**: Reduces total dungeon size by ~16% (for 3x3 rooms)
4. **Connection Logic**: Prevents invalid connections through walls

## Testing

To test the overlap system:

1. **Create rooms with blocked outer edges** using the MetaRoom editor
2. **Add connections** on blocked edge cells
3. **Run the dungeon generator** (test_dungeon scene)
4. **Verify**:
   - Rooms share edge cells
   - Total width/height is reduced by overlap count
   - Opposing connections are removed
   - No gaps between connected rooms

## Debugging

Enable debug output by checking the console when generation runs:
- Room placement positions
- Overlap detections
- Connection merging actions

Add print statements in:
- `_can_place_room()` - to see overlap checks
- `_merge_overlapping_cells()` - to see connection removals
- `_place_room()` - to see placement details

## Future Enhancements

Potential improvements:
1. **Variable overlap depths**: Allow rooms to overlap by more than 1 cell
2. **Partial overlaps**: Allow some non-blocked cells to overlap in special cases
3. **Overlap statistics**: Track and report overlap efficiency metrics
4. **Visual debugging**: Highlight overlapped cells in the visualizer
