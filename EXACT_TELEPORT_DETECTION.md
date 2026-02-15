# Exact Teleport Detection

This document describes the change from heuristic to exact teleport detection for walker movement visualization.

## Problem Statement

Previously, the system used a heuristic to determine if a walker movement was a teleport:

```gdscript
# OLD HEURISTIC METHOD
func _is_teleport_move(from_pos: Vector2i, to_pos: Vector2i) -> bool:
    var delta = to_pos - from_pos
    var manhattan_dist = abs(delta.x) + abs(delta.y)
    return manhattan_dist > teleport_distance_threshold  # Threshold was 10
```

**Issues with heuristic approach:**
- **Inexact**: Used arbitrary distance threshold (default: 10 cells)
- **False Positives**: Large adjacent rooms could be classified as teleports
- **False Negatives**: Small teleports might not be detected
- **Configuration Required**: Needed manual threshold tuning for different dungeon designs
- **Arbitrary**: No principled basis for threshold value

## Solution

Replace the heuristic with exact tracking of teleport events. The generator knows exactly when a walker teleports (respawns), so it can provide this information directly.

### Implementation

#### 1. Signal Enhancement

**Before:**
```gdscript
signal walker_moved(walker: Walker, from_pos: Vector2i, to_pos: Vector2i)
```

**After:**
```gdscript
signal walker_moved(walker: Walker, from_pos: Vector2i, to_pos: Vector2i, is_teleport: bool)
```

#### 2. Generator Changes

**Normal room placement (not a teleport):**
```gdscript
# Walker placed adjacent room normally
walker_moved.emit(walker, old_pos, walker.current_room.position, false)
```

**Respawn at different location (is a teleport):**
```gdscript
# Walker respawned at distant location
walker_moved.emit(walker, old_pos, spawn_target.position, true)
```

**Respawn at same location (no movement):**
```gdscript
# Walker respawned at current position - no signal needed
# Position didn't change, so no visual teleport
```

#### 3. Visualizer Changes

**Added tracking:**
```gdscript
var walker_teleports: Dictionary = {}  # walker_id -> Array[bool]

func _on_walker_moved(walker, from_pos, to_pos, is_teleport: bool):
    # Store exact teleport flag for this segment
    if not walker_teleports.has(walker.walker_id):
        walker_teleports[walker.walker_id] = []
    walker_teleports[walker.walker_id].append(is_teleport)
```

**Using exact flags:**
```gdscript
func _draw_walker_paths(offset: Vector2):
    var teleport_flags = walker_teleports.get(walker.walker_id, [])
    
    for i in range(walker.path_history.size() - 1):
        # Get exact teleport information
        var is_teleport = false
        if i < teleport_flags.size():
            is_teleport = teleport_flags[i]
        
        # Draw dashed line for teleports, solid for normal moves
        if is_teleport:
            _draw_dashed_line(...)
        else:
            draw_line(...)
```

## What Changed

### Removed
- ❌ `teleport_distance_threshold` export variable
- ❌ `_is_teleport_move()` heuristic function
- ❌ Manhattan distance calculation for teleport detection

### Added
- ✅ `is_teleport` parameter to `walker_moved` signal
- ✅ `walker_teleports` dictionary in visualizer
- ✅ Exact teleport tracking per walker path segment

### Modified
- 📝 All `walker_moved.emit()` calls now include teleport flag
- 📝 Path drawing uses exact flags instead of heuristic
- 📝 Signal documentation updated

## Benefits

### 1. 100% Accuracy
- No false positives (large rooms incorrectly marked as teleports)
- No false negatives (small teleports missed by threshold)
- Every teleport is correctly identified

### 2. No Configuration Needed
- No arbitrary threshold to set
- Works correctly out of the box
- No manual tuning for different dungeon designs

### 3. Works with Any Room Sizes
- Large rooms (10x10+): Correctly shown as non-teleports
- Small teleports (5 cells): Correctly shown as teleports
- No distance-based assumptions

### 4. Cleaner Code
- Less code overall (removed heuristic function)
- More maintainable (source of truth in generator)
- Easier to understand (explicit is better than implicit)

### 5. Future-Proof
- Adding new teleport types: Just set flag in generator
- Changing room sizes: No reconfiguration needed
- Different movement patterns: Automatically handled

## Technical Details

### Signal Flow

```
Generator                 Visualizer
---------                 ----------
Normal Move:
  place_room()
  walker_moved(false) --> store false in walker_teleports
                          draw solid line

Teleport:
  respawn_walker()
  walker_moved(true)  --> store true in walker_teleports
                          draw dashed line
```

### Data Structure

```gdscript
walker_teleports = {
    0: [false, false, true, false, false],  # Walker 0 teleported at index 2
    1: [false, true, false, false, true],   # Walker 1 teleported at indices 1 and 4
}

# Matches with path_history:
walker.path_history = [pos0, pos1, pos2, pos3, pos4, pos5]
#                       |_____|_____|_____|_____|_____|
#                       seg0  seg1  seg2  seg3  seg4
#                       false true  false false true
```

### Edge Cases Handled

1. **Respawn at same position**: No signal emitted (no movement)
2. **Initial spawn**: `is_teleport=false` (first position)
3. **Empty teleport flags**: Defaults to `false` (normal move)
4. **New walker added**: Teleports dictionary initialized

## Comparison

### Before (Heuristic)

```gdscript
# Configuration needed
@export var teleport_distance_threshold: int = 10

# Calculation for each segment
func _is_teleport_move(from_pos, to_pos) -> bool:
    var manhattan_dist = abs(delta.x) + abs(delta.y)
    return manhattan_dist > teleport_distance_threshold

# Problems:
# - What if rooms are 12 cells apart but adjacent?
# - What if teleport is 8 cells (below threshold)?
# - Need different thresholds for different dungeons?
```

### After (Exact)

```gdscript
# No configuration needed

# Generator knows exactly when teleporting
walker_moved.emit(walker, old_pos, new_pos, true)  # It's a teleport!

# Visualizer uses exact information
var is_teleport = teleport_flags[i]  # No guessing!

# Benefits:
# - Always correct
# - No configuration
# - Works with any room sizes
```

## Migration Notes

### For Existing Code

The change is backward compatible in behavior but not in API:
- Signal signature changed (added parameter)
- Export variable removed (may need scene updates)

### For Custom Visualizers

If you have custom code using `walker_moved` signal:

**Before:**
```gdscript
generator.walker_moved.connect(func(walker, from_pos, to_pos):
    # Your code
)
```

**After:**
```gdscript
generator.walker_moved.connect(func(walker, from_pos, to_pos, is_teleport):
    # Your code - now has exact teleport info!
)
```

## Testing

To verify the change works correctly:

1. Generate a dungeon with step-by-step visualization
2. Observe walker paths
3. Verify:
   - Normal room placements: **Solid lines**
   - Respawns to different locations: **Dashed lines**
   - No false classifications

Expected results:
- Most paths: Solid (normal adjacent placement)
- Occasional dashed lines: True teleports when walker respawns
- No dashed lines between adjacent large rooms

## Performance

**Before:** O(1) distance calculation per segment at draw time

**After:** O(1) array lookup per segment at draw time

Net effect: **No performance change** (same complexity, different operation)

Memory: **Negligible** (one boolean per path segment)

## Related Documentation

- Signal changes: See `dungeon_generator.gd` line 123
- Teleport tracking: See `dungeon_visualizer.gd` line 28
- Path drawing: See `_draw_walker_paths()` function

## Conclusion

The change from heuristic to exact teleport detection provides:
- ✅ 100% accuracy
- ✅ No configuration needed
- ✅ Cleaner, more maintainable code
- ✅ Works with any dungeon design
- ✅ Future-proof

The system now has a single source of truth (the generator) for teleport information, eliminating the need for guesswork based on distance thresholds.
