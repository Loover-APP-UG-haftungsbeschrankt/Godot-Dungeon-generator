# Multi-Walker Dungeon Generation Algorithm

## Overview

The multi-walker algorithm creates dungeons by having multiple independent "walkers" simultaneously place rooms. This approach creates more organic, interconnected dungeons with natural loops and better connectivity compared to single-walker random walks.

## Core Concepts

### Walker Class

Each walker is an independent entity that:
- Has a current room position
- Tracks how many rooms it has placed
- Has an alive/dead status
- Dies after placing a maximum number of rooms
- Respawns when it dies (maintaining constant exploration pressure)

```gdscript
class Walker:
    var current_room: PlacedRoom  # Current position
    var rooms_placed: int = 0     # Counter
    var is_alive: bool = true     # Status
    var max_rooms: int            # Death threshold
```

### Open Connections

An "open connection" is a connection point on a room that doesn't currently lead to another room. This is crucial for:
- Determining where walkers can place rooms
- Finding valid teleport destinations
- Creating loops (walkers can connect to existing rooms)

## Algorithm Flow

### 1. Initialization

```gdscript
# Place first room at origin
place_room(first_room, Vector2i.ZERO)

# Spawn initial walkers
for i in num_walkers:
    spawn_walker_at(first_room)
```

### 2. Main Generation Loop

```gdscript
while total_cells < target_cell_count:
    for each walker:
        if walker.is_alive:
            # Try to place a room
            if place_room_success:
                walker.rooms_placed++
                walker.check_death()
                if walker.is_dead:
                    respawn_walker(walker)
            else:
                # Failed - teleport or die
                if can_teleport:
                    walker.teleport_to_random_room_with_open_connections()
                else:
                    walker.die()
                    respawn_walker(walker)
```

### 3. Walker Room Placement

Each walker attempts to place a room:

1. **Get open connections** from current room
2. **Shuffle connections** for randomness
3. **For each connection**:
   - Try up to `max_placement_attempts_per_room` times
   - Pick random template and rotation
   - Try to connect room
   - If successful, place and move to new room
4. **If all fail**, return false (triggers teleport/death)

### 4. Walker Death and Respawn

When a walker dies:
1. Find a random room with open connections
2. Reset walker's room counter
3. Set walker to alive
4. Position at new room

This ensures:
- Constant exploration pressure
- New growth points emerge
- Dungeons fill more evenly

## Key Features

### Loop Creation

Unlike single-walker algorithms that avoid revisiting rooms, multi-walker allows connections to existing rooms:

```
Walker A places: Room1 → Room2 → Room3
                                     ↓
Walker B places: Room4 → Room5 → Room6
                         ↑
                    Creates loop!
```

This naturally creates:
- Multiple paths between areas
- Fewer dead ends
- More interesting exploration

### Teleportation

When a walker gets stuck (no valid placements after 10 tries):
1. Find all rooms with open connections
2. Pick one randomly
3. Teleport walker there

This prevents:
- Walkers clustering in one area
- Early termination due to local dead ends
- Uneven dungeon growth

### Cell-Count Based Termination

Instead of counting rooms, count total cells:
- More predictable dungeon size
- Large rooms contribute more
- Better control over dungeon density

```gdscript
func _count_total_cells() -> int:
    var total = 0
    for placement in placed_rooms:
        for each cell in room:
            if cell != null:
                total++
    return total
```

## Example Generation Trace

```
Initial: [Room1(0,0)]
Walkers: W1, W2, W3 at Room1

Iteration 1:
  W1: Place Room2 at (3,0) - connected right
  W2: Place Room3 at (0,3) - connected bottom
  W3: Place Room4 at (-3,0) - connected left
  
State: Room1 has 4 rooms around it, 1 connection still open (top)

Iteration 2:
  W1: Place Room5 from Room2
  W2: Place Room6 from Room3
  W3: Failed, teleport to Room2
  
Iteration 3:
  W1: Place Room7 from Room5
  W2: Failed, teleport to Room4
  W3: Place Room8 from Room2 - connects to Room1's top!
  
State: Loop created! Room1 ↔ Room2 ↔ Room8 ↔ Room1

Continue until cell count >= 500...
```

## Configuration Guidelines

### num_walkers (default: 3)

- **Low (1-2)**: More linear dungeons, snake-like
- **Medium (3-5)**: Balanced, organic layouts
- **High (6+)**: Dense, highly connected dungeons

### max_rooms_per_walker (default: 20)

- **Low (5-10)**: More walker respawns, chaotic growth
- **Medium (15-25)**: Balanced growth patterns
- **High (30+)**: Longer walker paths, more linear branches

### max_placement_attempts_per_room (default: 10)

- **Low (3-5)**: Faster but more teleports
- **Medium (8-12)**: Good balance
- **High (15+)**: Fewer teleports but slower

### target_meta_cell_count (default: 500)

- Depends on room sizes and actual cell content
- 3x3 rooms with ~7-8 non-null cells: 500 cells ≈ 60-70 rooms
- 5x5 rooms with ~20-23 non-null cells: 500 cells ≈ 22-25 rooms
- Mixed sizes: Varies based on room composition
- Note: Rooms may have null cells or blocked edges affecting total count

## Advantages Over Single Walker

1. **More Organic**: Multiple growth points create natural-looking dungeons
2. **Better Connectivity**: Walkers meet and create loops naturally
3. **Fewer Dead Ends**: Multiple paths and connections
4. **Balanced Growth**: Walkers spread out via teleportation
5. **Predictable Size**: Cell-count based termination
6. **Fault Tolerant**: If one walker gets stuck, others continue

## Implementation Notes

### Walker Independence

Each walker operates independently:
- No coordination between walkers
- No exclusive territories
- Can place rooms anywhere valid
- Can connect to any room with open connections

### Safety Mechanisms

1. **Max Iterations**: Prevents infinite loops (10,000 iterations)
2. **Walker Death**: Prevents walkers walking forever
3. **Teleportation**: Prevents local dead ends from stopping generation
4. **Respawning**: Ensures constant exploration pressure

### Performance

- Dictionary lookup for collision: O(1)
- Walker iteration: O(num_walkers)
- Room placement: O(connections × attempts × templates × rotations)
- Typical: < 200ms for 500 cells

## Future Enhancements

Possible improvements:
- **Walker priorities**: Some walkers prefer certain room types
- **Coordinated spawning**: Spawn walkers far apart
- **Territory hints**: Guide walkers to unexplored areas
- **Dynamic walker count**: Adjust based on open connections
- **Walker memory**: Avoid recently tried locations
