# Visual Explanation of the Bug

## How Connections Should Work

### Scenario: Placing a T-Room

```
STEP 1: T-Room wants to connect via its BOTTOM connection
┌─────────────┐
│   T-ROOM    │
│  ▓▓▓▓▓▓▓▓▓  │  ▓ = BLOCKED cells with connections
│ ◄▓         ▓►│  ◄ = LEFT connection (required)
│  ▓▓▓ ▓▓▓▓▓  │  ► = RIGHT connection (required)
│      ▼      │  ▼ = BOTTOM connection (required)
└─────────────┘
       │
  connects to
       │
       ▼
┌─────────────┐
│   Room A    │
│   ▲         │  ▲ = UP connection (matches BOTTOM)
│   █████     │  █ = FLOOR cells
└─────────────┘
```

### Validation Should Check

For the LEFT and RIGHT connections that aren't being used to connect:

```
LEFT CONNECTION (◄):
┌─────────┐  ???  ┌─────────────┐
│ Room B? │ <-?-> │◄▓         ▓►│
│         │       │  ▓▓▓ ▓▓▓▓▓  │
└─────────┘       └─────────────┘
                       T-ROOM

Question: Does Room B have a cell with RIGHT connection (►) that points back?

Current code: Only checks if Room B exists
SHOULD check: Room B exists AND has matching connection
```

## The Bug in Detail

### What Current Code Checks ❌

```gdscript
# In _can_fulfill_required_connections():

# 1. Check if a room exists at adjacent position
if not occupied_cells.has(adjacent_pos):
    return false

# 2. Check if that room is a connection room
var existing_placement = occupied_cells[adjacent_pos]
if existing_placement.room.is_connection_room():
    return false

# 3. Accept! ✓ 
# PROBLEM: Never checks if the adjacent cell has a matching connection!
return true
```

### What Happens in Reality

```
T-Room placed next to Room B:

┌─────────┐     ┌─────────────┐
│ Room B  │     │             │
│         │     │◄▓         ▓►│  ◄ This connection points to Room B
│  █████  │ ??? │  ▓▓▓ ▓▓▓▓▓  │  but Room B has no matching connection!
│         │     │      ▼      │
└─────────┘     └─────────────┘
                     T-ROOM
     ^
     |
  NO RIGHT CONNECTION HERE!
  
Result:
- T-room's LEFT connection (◄) points to a FLOOR cell with no connection
- No door is created
- Connection is unfulfilled
- T-room is "floating" - not fully connected to the dungeon
```

### Correct Validation Flow ✅

```
1. T-room wants LEFT connection at (0,1) fulfilled
   - This is a BLOCKED cell with connection_left=true
   - Adjacent position is (-1,1)

2. Check if room exists at (-1,1)
   ✓ Room B exists

3. Check if Room B is a connection room
   ✓ It's a normal room

4. NEW CHECK: Get cell at (-1,1) from Room B
   - Cell type: FLOOR
   - Connections: connection_up=true, others=false
   - Does it have connection_right=true? NO!
   ✗ REJECT: Adjacent cell doesn't have matching connection

5. Try different placement or rotation
```

## Why This Causes the Observed Issues

### Issue 1: T-rooms not appearing

```
T-room has 3 required connections: LEFT, RIGHT, BOTTOM

When trying to place:
- Connect via BOTTOM (1 connection satisfied)
- Must validate LEFT and RIGHT are pre-satisfied
- For each:
  * Room must exist at adjacent position
  * Room must be normal (not connection room)
  * [MISSING] Adjacent cell must have matching connection

Without the last check:
- Validation often passes (rooms exist)
- But connections don't actually match
- In practice, this should FAIL most of the time
- So either:
  a) T-rooms rarely appear (validation randomly passes)
  b) T-rooms appear but connections unfulfilled

Actually, the fact that T-rooms DON'T appear suggests
the validation IS failing, but for wrong reasons.

Wait... if validation is passing incorrectly, why don't T-rooms appear?

Let me reconsider...
```

### Actually, Let Me Reconsider

The user says:
- "T-rooms are not appearing" 
- "L-rooms don't have all their connections fulfilled"

This suggests:
- T-rooms: Validation is **too strict** (rejecting valid placements)
- L-rooms: Validation is **too lenient** (accepting invalid placements)

But my analysis shows validation is too **lenient** (not checking matching connections).

So how can T-rooms not appear?

**Answer**: T-rooms DON'T appear because:
- The validation is too lenient (accepts without checking matching connections)
- T-rooms get placed
- But their connections are unfulfilled
- So they don't integrate well with the dungeon
- The game logic might then reject them or they cause issues

OR more likely:
- T-rooms rarely have ALL required connections pre-satisfied
- Even with lenient validation, finding 2+ adjacent rooms is rare
- So T-rooms are rejected during validation (no adjacent rooms at all)
- L-rooms only need 1 adjacent room (plus the connecting one)
- So L-rooms pass validation more often
- But their connections aren't actually matching

Actually wait, if we're connecting via one connection, we need N-1 other
connections pre-satisfied:
- T-room: Connect via 1, need 2 others pre-satisfied (hard!)
- L-room: Connect via 1, need 1 other pre-satisfied (easier)

So:
- T-rooms rarely have 2 adjacent rooms → rarely placed
- L-rooms more often have 1 adjacent room → placed more often
- But neither checks if connections match → connections unfulfilled
