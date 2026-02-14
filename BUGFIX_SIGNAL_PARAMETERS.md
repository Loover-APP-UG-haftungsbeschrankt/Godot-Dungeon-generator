# Signal Parameter Mismatch - Fix Documentation

## Problem

When running the dungeon generator, the following error occurred:

```
E 0:00:07:140   dungeon_generator.gd:172 @ generate(): 
Error calling from signal 'generation_complete' to callable: 
'Node2D(dungeon_visualizer.gd)::_on_generation_complete': 
Method expected 2 argument(s), but called with 3.
```

## Root Cause

The `generation_complete` signal was updated to emit 3 parameters:
```gdscript
signal generation_complete(success: bool, room_count: int, cell_count: int)
```

However, the signal handler in `dungeon_visualizer.gd` still expected only 2 parameters:
```gdscript
func _on_generation_complete(success: bool, room_count: int) -> void:
```

## Fix Applied

### 1. Updated Signal Handler (dungeon_visualizer.gd line 37)

**Before:**
```gdscript
func _on_generation_complete(success: bool, room_count: int) -> void:
	print("Dungeon generation complete. Success: ", success, ", Rooms: ", room_count)
	queue_redraw()
```

**After:**
```gdscript
func _on_generation_complete(success: bool, room_count: int, cell_count: int) -> void:
	print("Dungeon generation complete. Success: ", success, ", Rooms: ", room_count, ", Cells: ", cell_count)
	queue_redraw()
```

### 2. Updated Statistics Display (dungeon_visualizer.gd line 109)

**Issue Found:** The statistics display referenced `generator.target_room_count`, which no longer exists.

**Before:**
```gdscript
var stats = [
	"Rooms: %d / %d" % [generator.placed_rooms.size(), generator.target_room_count],
	"Bounds: %d x %d" % [bounds.size.x, bounds.size.y],
	"Seed: %d" % generator.generation_seed
]
```

**After:**
```gdscript
var cell_count = 0
for placement in generator.placed_rooms:
	for y in range(placement.room.height):
		for x in range(placement.room.width):
			var cell = placement.room.get_cell(x, y)
			if cell != null:
				cell_count += 1

var stats = [
	"Rooms: %d" % generator.placed_rooms.size(),
	"Cells: %d / %d" % [cell_count, generator.target_meta_cell_count],
	"Bounds: %d x %d" % [bounds.size.x, bounds.size.y],
	"Seed: %d" % generator.generation_seed
]
```

## Testing Instructions

1. Open the project in Godot 4.6
2. Press F5 to run the test scene (`scenes/test_dungeon.tscn`)
3. Verify:
   - No error messages appear
   - Dungeon generates successfully
   - Statistics display shows:
     - Number of rooms placed
     - Cell count vs target cell count
     - Dungeon bounds
     - Generation seed
4. Test regeneration:
   - Press R to regenerate with same seed
   - Press S to generate with new random seed
5. Verify console output shows:
   ```
   Dungeon generation complete. Success: true, Rooms: X, Cells: Y
   ```

## Changes Summary

**Files Modified:**
- `scripts/dungeon_visualizer.gd`
  - Updated `_on_generation_complete()` to accept 3 parameters
  - Updated `_draw_statistics()` to display cell count instead of room count target
  - Calculates actual cell count for display

**Breaking Changes:** None - this is a bug fix

**Backward Compatibility:** Fully compatible - fixes regression from multi-walker implementation
