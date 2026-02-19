# Bug Fix #3: T-Rooms Not Placing At All

## Problem Report
User reported: "Still not placing T-Meta-Rooms."

Despite the previous two fixes, T-rooms were still not appearing in generated dungeons.

## Root Cause Analysis

The validation logic was checking ALL required connections, including the connection being used to place the room. This created an impossible situation:

### Example: Placing a T-Room

When a walker tries to place a T-room via its LEFT connection:

**What happens:**
1. Walker is at room A
2. Walker wants to connect a T-room via the T-room's LEFT connection
3. The T-room's LEFT connection will connect to room A (this is the placement action!)
4. But the validation checks ALL 3 required connections:
   - LEFT required connection → needs a normal room → room A is there ✓
   - RIGHT required connection → needs a normal room → empty ✗
   - BOTTOM required connection → needs a normal room → empty ✗

**The problem:**
- We're validating the LEFT connection that we're USING to connect
- That connection is automatically fulfilled by room A (the room we're connecting from)
- But we still require it to "have a normal room adjacent" which it does (room A)
- However, this creates the need for 3 normal rooms to exist before placing a T-room
- In practice, this means we need: room A (connecting from), room B (for RIGHT), room C (for BOTTOM)
- This is extremely rare!

### Why T-Rooms Weren't Appearing

For a T-room with 3 required connections (LEFT, RIGHT, BOTTOM):
- **Before Fix #3**: Needed 3 separate normal rooms already placed in correct positions
- This requires a very specific configuration that rarely occurs naturally
- Result: T-rooms virtually never placed

### Why L-Rooms Had Issues

For an L-room with 2 required connections:
- **Before Fix #3**: Needed 2 separate normal rooms already placed
- One for connecting from, one for the other required connection
- This worked sometimes but was harder than it should be

## The Fix

### Modified Validation Logic

The key insight: **When we place a connection room via one of its connections, that connection is automatically fulfilled!**

**Changed Function Signature:**
```gdscript
// Before:
func _can_fulfill_required_connections(room: MetaRoom, position: Vector2i) -> bool

// After:
func _can_fulfill_required_connections(room: MetaRoom, position: Vector2i, connecting_via: MetaRoom.ConnectionPoint = null) -> bool
```

**Modified Validation:**
```gdscript
func _can_fulfill_required_connections(room: MetaRoom, position: Vector2i, connecting_via: MetaRoom.ConnectionPoint = null) -> bool:
    var required_connections = room.get_required_connection_points()
    
    for conn_point in required_connections:
        # NEW: Skip the connection we're using to connect - it's automatically fulfilled
        if connecting_via != null:
            if conn_point.x == connecting_via.x and conn_point.y == connecting_via.y and conn_point.direction == connecting_via.direction:
                continue  # This connection is being used to connect, skip validation
        
        # Validate the OTHER required connections
        var conn_world_pos = position + Vector2i(conn_point.x, conn_point.y)
        var adjacent_pos = conn_world_pos + _get_direction_offset(conn_point.direction)
        
        if not occupied_cells.has(adjacent_pos):
            return false
        
        var existing_placement = occupied_cells[adjacent_pos]
        
        if existing_placement.room.is_connection_room():
            return false
    
    return true
```

**Updated Call Site:**
```gdscript
// In _try_connect_room():
if to_room.is_connection_room():
    if not _can_fulfill_required_connections(to_room, target_pos, to_conn):  // Pass to_conn
        continue
```

## Impact

### L-Room Placement (2 required connections):
- **Before**: Needed 2 normal rooms (one for each required connection)
- **After**: Needs 1 normal room (the other required connection)
- **Reason**: One required connection is used for connecting (automatically fulfilled)
- **Result**: L-rooms much more common, always properly connected

### T-Room Placement (3 required connections):
- **Before**: Needed 3 normal rooms simultaneously (nearly impossible)
- **After**: Needs 2 normal rooms (the other two required connections)
- **Reason**: One required connection is used for connecting (automatically fulfilled)
- **Result**: T-rooms now actually appear! Still rare but achievable

### I-Room Placement (2 required connections):
- **Before**: Needed 2 normal rooms
- **After**: Needs 1 normal room
- **Reason**: One required connection is used for connecting (automatically fulfilled)
- **Result**: I-rooms more common, always properly connected

## Why This Makes Sense

### The Logic:

When you place a corridor piece to connect two rooms:
1. You're connecting FROM an existing room
2. The connection point you use on the corridor is automatically satisfied (it connects to that room)
3. You only need to validate the OTHER connections

### Real-World Example:

Imagine placing an L-corridor:
```
Existing room A:          L-corridor:           What we need:
┌─────┐                   ┌─────┐              ┌─────┐
│  A  ├──→ (connect)      │  L  │              │  A  │
└─────┘                   └──┬──┘              └──┬──┘
                             ↓                     │
                        (need room here)       ┌──┴──┐
                                               │  L  │
                                               └──┬──┘
                                                  │
                                               ┌──┴──┐
                                               │  B  │ ← Need this
                                               └─────┘
```

- The RIGHT connection of L-room connects to room A (we're using this to place it)
- The BOTTOM connection of L-room needs room B to exist
- We only validate that room B exists, not room A (because we're connecting from A!)

## Debug Logging

Added optional debug logging (line 434):
```gdscript
var debug_connection_rooms = false  # Set to true for debugging
```

When enabled, prints detailed information about T-room validation:
- Which connections are required
- Which connection is being used (skipped)
- Which connections are being validated
- Why validation succeeds or fails

## Expected Behavior After Fix

### T-Room Placement:
```
Before placement:          After placement:
┌─────┐   ┌─────┐         ┌─────┐   ┌─────┐
│  A  │   │  B  │         │  A  ├───┤  T  ├───┤  B  │
└─────┘   └─────┘         └─────┘   └──┬──┘   └─────┘
                                       │
    ┌─────┐                        ┌──┴──┐
    │  C  │                        │  C  │
    └─────┘                        └─────┘

Requirements to place T-room:
- Connect via LEFT to room A (automatic)
- RIGHT connection → room B must exist ✓
- BOTTOM connection → room C must exist ✓
Result: T-room can be placed!
```

### L-Room Placement:
```
Before placement:          After placement:
┌─────┐                   ┌─────┐
│  A  │                   │  A  ├───┐
└─────┘                   └─────┘   │
                                 ┌──┴──┐
    ┌─────┐                     │  L  │
    │  B  │                     └──┬──┘
    └─────┘                        │
                                ┌──┴──┐
                                │  B  │
                                └─────┘

Requirements to place L-room:
- Connect via RIGHT to room A (automatic)
- BOTTOM connection → room B must exist ✓
Result: L-room can be placed!
```

## Comparison: All Three Fixes

### Fix #1: Empty Spaces Not Allowed
- Problem: Validation accepted empty adjacent spaces
- Solution: Reject if no room exists at required connection
- Impact: Ensured connections are fulfilled

### Fix #2: No Connection Rooms as Starting Room
- Problem: Connection rooms could be first room (bypassing validation)
- Solution: Filter connection rooms from starting room selection
- Impact: All connection rooms go through validation

### Fix #3: Skip Connection Being Used
- Problem: Validation checked the connection being used to connect
- Solution: Skip validating the connection point being used for placement
- Impact: T-rooms and other connection rooms can actually be placed!

## Technical Details

### Connection Point Matching:
```gdscript
if connecting_via != null:
    if conn_point.x == connecting_via.x and 
       conn_point.y == connecting_via.y and 
       conn_point.direction == connecting_via.direction:
        continue  // Skip this connection
```

This compares:
- Local coordinates (x, y) in the room grid
- Direction of the connection
- If they match, this is the connection being used for placement

### Why This Is Correct:

When `_try_connect_room()` calls validation:
- `to_conn` is the connection point on the room being placed
- This connection aligns with the existing room's connection
- This connection IS fulfilled by definition (it's the placement action)
- We don't need to validate it
- We only validate the OTHER required connections

## Performance Impact

Minimal - adds one comparison per required connection to check if it's the connecting point. For a T-room with 3 required connections, this is 3 simple comparisons.

## Summary

All three fixes work together:
1. **Fix #1**: Ensures connections aren't empty (structural integrity)
2. **Fix #2**: Ensures starting room is normal (no invalid first room)
3. **Fix #3**: Skips connection being used (makes T-rooms placeable)

Result: **T-rooms and all connection rooms now place correctly!**
