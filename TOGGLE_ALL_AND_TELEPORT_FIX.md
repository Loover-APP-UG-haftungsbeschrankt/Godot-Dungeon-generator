# Toggle All Walkers and Teleport Fix

This document describes the improvements made to walker visualization toggling and teleport behavior.

## Issues Fixed

### 1. Teleport Logic Bug
**Problem**: Walkers were always teleporting to the same location (typically near dungeon center).

**Root Cause**: 
```gdscript
var should_spawn_at_current_position = randf() < 0.0  # Always false!
```
The condition `randf() < 0.0` always evaluates to `false` since `randf()` returns a value between 0.0 and 1.0. This meant walkers never stayed at their current position and always teleported to a random room with open connections, which was usually the same location due to the compactness bias favoring rooms near the dungeon center.

**Solution**:
```gdscript
var should_spawn_at_current_position = randf() < 0.5  # Proper 50% chance
```
Changed to `randf() < 0.5` to give a true 50% chance for walkers to stay at their current position vs teleporting to another room.

**Impact**:
- ✅ Walkers now have varied teleport destinations
- ✅ 50% chance to stay at current position if it has open connections
- ✅ 50% chance to teleport to a random room with open connections
- ✅ More organic dungeon generation patterns

### 2. Toggle All Walkers Feature
**Problem**: Could only toggle individual walker paths one at a time, no way to toggle all at once.

**Solution**: Added "Toggle All" functionality with both UI button and keyboard shortcut.

**Implementation**:
1. **UI Button**: Added "Toggle All" button in walker selection panel
2. **Keyboard Shortcut**: Press 'A' key to toggle all walker paths
3. **Smart Toggle Logic**: 
   - If any walker paths are disabled → Enable all
   - If all walker paths are enabled → Disable all

**Code**:
```gdscript
func _on_toggle_all_pressed() -> void:
    # Determine if we should enable or disable all
    var any_disabled = false
    for walker_id in visible_walker_paths:
        if not visible_walker_paths[walker_id]:
            any_disabled = true
            break
    
    var new_state = any_disabled  # Enable if any disabled
    
    # Toggle all walker paths
    for walker_id in visible_walker_paths:
        visible_walker_paths[walker_id] = new_state
        # Sync with checkbox if it exists
        if walker_checkboxes.has(walker_id):
            walker_checkboxes[walker_id].button_pressed = new_state
```

### 3. UI Updates During Generation
**Problem**: Walker selection UI was only created after generation completed, so you couldn't toggle walkers during generation.

**Solution**: Added dynamic UI updates when walkers spawn/respawn during generation.

**Implementation**:
```gdscript
func _on_walker_moved(walker: DungeonGenerator.Walker, from_pos: Vector2i, to_pos: Vector2i) -> void:
    walker_positions[walker.walker_id] = to_pos
    _update_walker_count()
    # Update UI if needed (e.g., if new walker spawned during generation)
    _update_walker_selection_ui_if_needed()
    queue_redraw()

func _update_walker_selection_ui_if_needed() -> void:
    if walker_checkboxes.size() != generator.active_walkers.size():
        _update_walker_selection_ui()
```

**Impact**:
- ✅ Can now toggle walker visibility during generation
- ✅ UI automatically updates when walkers spawn/respawn
- ✅ No need to wait for generation to complete

## Usage

### Toggle All Walkers

**Button**: Click "Toggle All" button in the walker selection panel (top-right corner)

**Keyboard**: Press `A` key

**Behavior**:
- If any walker paths are hidden → Shows all walker paths
- If all walker paths are visible → Hides all walker paths

### Individual Walker Toggle

**UI**: Click individual walker checkboxes in the walker selection panel

**Keyboard**: Press number keys `0-9` for walkers 0-9

### During Generation

All toggle controls work during generation:
1. Enable step-by-step mode with `V` key
2. Start generation with `R` or `S` key
3. Toggle walker visibility as generation progresses
4. UI updates automatically when walkers spawn/respawn

## Technical Details

### Files Modified

1. **scripts/dungeon_generator.gd**
   - Fixed `_respawn_walker()` teleport logic

2. **scripts/dungeon_visualizer.gd**
   - Added `_on_toggle_all_pressed()` handler
   - Added `_update_walker_selection_ui_if_needed()` helper
   - Modified `_on_walker_moved()` to update UI during generation
   - Connected "Toggle All" button in `_ready()`
   - Added 'A' key handler in `_input()`

3. **scenes/test_dungeon.tscn**
   - Added "Toggle All" button to walker selection panel
   - Updated help text with 'A' key documentation

### Performance

- **UI Updates**: Only rebuilds UI when walker count changes (minimal overhead)
- **Toggle All**: O(n) where n = number of walkers (typically 2-5)
- **No Impact**: No performance impact on generation or rendering

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `A` | Toggle all walker paths |
| `0-9` | Toggle individual walker path |
| `W` | Toggle walker markers |
| `P` | Toggle walker paths |
| `N` | Toggle step numbers |

## Testing Checklist

- [x] Syntax validation passed
- [x] Teleport logic fixed (walkers show varied teleport destinations)
- [x] "Toggle All" button works correctly
- [x] 'A' key toggles all walker paths
- [x] UI updates during generation when walkers spawn
- [x] Toggle behavior correct (smart enable/disable logic)
- [x] Individual toggles still work
- [x] Documentation updated

## Before/After Comparison

### Teleport Behavior

**Before**:
```
Walker teleports → Always same location (near center)
Walker teleports → Always same location (near center)
Walker teleports → Always same location (near center)
❌ Predictable, boring patterns
```

**After**:
```
Walker teleports → Random room A
Walker stays → Current position
Walker teleports → Random room B
✅ Varied, organic patterns
```

### Toggle Functionality

**Before**:
```
- Toggle walker 0: Press '0' or click checkbox
- Toggle walker 1: Press '1' or click checkbox
- Toggle walker 2: Press '2' or click checkbox
❌ Tedious to toggle all walkers
❌ Can't toggle during generation
```

**After**:
```
- Toggle all: Press 'A' or click "Toggle All" button
- Works during generation
- Smart logic (enable if any disabled)
✅ Quick and convenient
✅ Works any time
```

## Related Documentation

- `BUGFIX_SUMMARY.md` - Recent bug fixes
- `WALKER_VISUALIZATION_IMPROVEMENTS.md` - Original walker visualization features
- `NEW_FEATURES_SUMMARY.md` - Complete feature list

