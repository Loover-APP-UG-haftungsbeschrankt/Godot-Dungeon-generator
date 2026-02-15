# Bug Fix: Dotted Lines Disappearing After Generation

This document describes the fix for a critical bug where teleport indicators (dotted lines) disappeared when dungeon generation finished.

## Problem Statement

"The dotted lines are removed when the generation finished."

Users reported that during generation, walker paths correctly showed dotted lines for teleports, but these dotted lines would disappear as soon as generation completed.

## Impact

### Before Fix
- ✅ Dotted lines visible during generation
- ❌ Dotted lines disappear when generation finishes
- ❌ Only solid lines shown in final visualization
- ❌ No way to see which moves were teleports

### After Fix
- ✅ Dotted lines visible during generation
- ✅ Dotted lines persist after generation
- ✅ Complete path history preserved
- ✅ Clear visualization of teleports vs normal moves

## Root Cause Analysis

### The Problem

In `_generate_and_visualize()` function (line 108), after generation completed successfully, the code called `_initialize_visible_walker_paths()`:

```gdscript
func _generate_and_visualize() -> void:
    var success = await generator.generate()
    if success:
        _initialize_visible_walker_paths()  // ❌ This was the problem!
        _update_walker_selection_ui()
        queue_redraw()
```

### What `_initialize_visible_walker_paths()` Does

```gdscript
func _initialize_visible_walker_paths() -> void:
    visible_walker_paths.clear()
    walker_teleports.clear()  // ❌ CLEARS ALL TELEPORT DATA!
    if generator == null:
        return
    for walker in generator.active_walkers:
        visible_walker_paths[walker.walker_id] = true
        walker_teleports[walker.walker_id] = []  // Creates empty arrays
```

This function:
1. Clears `visible_walker_paths` dictionary
2. **Clears `walker_teleports` dictionary** ← This is the problem!
3. Initializes empty arrays for each walker

### The Flow That Caused the Bug

```
1. _ready() called
   └─ _initialize_visible_walker_paths()
      └─ Sets up empty walker_teleports = {}

2. Generation starts
   └─ Walkers move and emit signals
      └─ _on_walker_moved(walker, from, to, is_teleport)
         └─ walker_teleports[id].append(is_teleport)
            └─ Data collected: walker_teleports = {0: [false, false, true, false], ...}

3. Generation completes ✅
   └─ _generate_and_visualize() finishes await
      └─ _initialize_visible_walker_paths() ❌
         └─ walker_teleports.clear()
            └─ ALL DATA LOST: walker_teleports = {}
         └─ New empty arrays: walker_teleports = {0: [], 1: []}

4. Drawing occurs
   └─ _draw_walker_paths()
      └─ var teleport_flags = walker_teleports.get(walker.walker_id, [])
         └─ teleport_flags = [] (empty!)
      └─ for i in range(...):
         └─ is_teleport = teleport_flags[i+1] if (i+1) < teleport_flags.size()
            └─ Always false (array is empty)
         └─ All lines drawn as solid (no dotted lines)
```

### Why This Function Was Called

The intention was probably to:
- Update the UI after generation
- Ensure walker visibility settings are initialized

However:
- The function does too much (initialization AND clearing)
- It was already called in `_ready()` before generation
- Calling it again after generation destroys collected data

## The Fix

### Change Made

**File**: `scripts/dungeon_visualizer.gd`
**Location**: `_generate_and_visualize()` function (line ~108)

**Before:**
```gdscript
func _generate_and_visualize() -> void:
    print("\n=== Generating Dungeon ===")
    var success = await generator.generate()
    if success:
        print("Generation successful! Rooms placed: ", generator.placed_rooms.size())
        _initialize_visible_walker_paths()  // ❌ REMOVED THIS LINE
        _update_walker_selection_ui()
        queue_redraw()
    else:
        print("Generation failed or incomplete")
```

**After:**
```gdscript
func _generate_and_visualize() -> void:
    print("\n=== Generating Dungeon ===")
    var success = await generator.generate()
    if success:
        print("Generation successful! Rooms placed: ", generator.placed_rooms.size())
        # Don't call _initialize_visible_walker_paths() here - it clears walker_teleports!
        # The function is already called in _ready() to set up empty data structures.
        # Calling it here would erase all teleport data collected during generation.
        _update_walker_selection_ui()
        queue_redraw()
    else:
        print("Generation failed or incomplete")
```

### Why This Works

1. `_initialize_visible_walker_paths()` is still called in `_ready()` (line 64)
   - Sets up empty data structures before generation
   - Initializes `walker_teleports` dictionaries

2. During generation:
   - `walker_teleports` gets populated with actual data
   - Each teleport flag is recorded correctly

3. After generation:
   - `_initialize_visible_walker_paths()` is NOT called
   - `walker_teleports` data is preserved
   - Dotted lines can be drawn correctly

4. `_update_walker_selection_ui()` is still called:
   - Updates the UI as needed
   - Doesn't clear teleport data

## Data Preservation

### walker_teleports Structure

The `walker_teleports` dictionary maps walker IDs to arrays of boolean flags:

```gdscript
walker_teleports = {
    0: [false, false, false, true, false, false],
    1: [false, false, true, false],
    // walker_id: [flag for each move]
}
```

Each flag indicates whether the move that created that position was a teleport.

### Why Preservation Matters

This data is critical for visualization:
- Shows the complete history of walker movements
- Distinguishes between normal moves (solid lines) and teleports (dotted lines)
- Provides insight into dungeon generation algorithm behavior
- Should persist after generation for analysis

### Before Fix: Data Loss

```
Generation starts:  walker_teleports = {}
During generation:  walker_teleports = {0: [false, true, false], 1: [false, false]}
Generation ends:    _initialize_visible_walker_paths() called
After clear:        walker_teleports = {}  // ❌ ALL DATA LOST
After init:         walker_teleports = {0: [], 1: []}  // Empty arrays
Visualization:      No dotted lines (no data to draw from)
```

### After Fix: Data Preserved

```
Generation starts:  walker_teleports = {}
During generation:  walker_teleports = {0: [false, true, false], 1: [false, false]}
Generation ends:    NO clear operation
After generation:   walker_teleports = {0: [false, true, false], 1: [false, false]}  // ✅ PRESERVED
Visualization:      Dotted lines correctly shown for teleports
```

## Testing

### Manual Test Steps

1. **Start the application**
   - Open Godot project
   - Run the test scene

2. **Enable step-by-step visualization**
   - Press `V` key to enable visualization
   - This allows you to see generation in progress

3. **Generate dungeon**
   - Press `R` or `S` to start generation
   - Watch for dotted lines during generation

4. **Wait for generation to complete**
   - Let generation finish completely
   - Message: "Generation successful!"

5. **Verify dotted lines persist**
   - Check that dotted lines are still visible
   - They should show walker teleports
   - Compare with solid lines (normal moves)

### Expected Results

**Before Fix:**
- During generation: Dotted lines visible ✅
- After generation: Dotted lines disappear ❌

**After Fix:**
- During generation: Dotted lines visible ✅
- After generation: Dotted lines still visible ✅

### Visual Indicators

Look for paths with:
- **Solid lines** `─────`: Normal adjacent room placement
- **Dotted lines** `┄┄┄┄┄`: Walker teleport/respawn

If you only see solid lines after generation, the bug is present.
If you see both solid and dotted lines, the fix is working.

## Related Code

### Key Functions

1. **_ready()**
   - Called once at initialization
   - Calls `_initialize_visible_walker_paths()` to set up empty structures
   - This is the RIGHT place for initialization

2. **_generate_and_visualize()**
   - Starts dungeon generation
   - Waits for completion
   - Should NOT reinitialize data structures
   - Should preserve collected data

3. **_on_walker_moved()**
   - Called during generation for each walker move
   - Appends teleport flags to `walker_teleports`
   - This is where data is collected

4. **_draw_walker_paths()**
   - Uses `walker_teleports` to decide line style
   - Dotted for teleports, solid for normal moves
   - Needs preserved data to work correctly

### Data Flow

```
Initialization:
  _ready()
    └─ _initialize_visible_walker_paths()
       └─ walker_teleports = {0: [], 1: []}

Collection:
  _on_walker_moved(walker, from, to, is_teleport)
    └─ walker_teleports[walker.walker_id].append(is_teleport)
    └─ walker_teleports = {0: [false, false, true], 1: [false]}

Visualization:
  _draw_walker_paths()
    └─ for each segment:
       └─ is_teleport = walker_teleports[walker_id][i+1]
       └─ if is_teleport: draw_dashed_line()
       └─ else: draw_line()
```

## Alternative Solutions Considered

### Option 1: Create New Function (Not Chosen)
Create separate functions for initialization and clearing:
```gdscript
func _initialize_walker_data():  // Only called in _ready()
    walker_teleports.clear()
    // ...

func _update_walker_visibility():  // Safe to call anytime
    visible_walker_paths.clear()
    // Don't clear walker_teleports
```

**Pros**: More explicit separation of concerns
**Cons**: More complex, requires refactoring

### Option 2: Add Parameter to Skip Clear (Not Chosen)
```gdscript
func _initialize_visible_walker_paths(clear_teleports: bool = true):
    if clear_teleports:
        walker_teleports.clear()
```

**Pros**: Backward compatible
**Cons**: Confusing API, easy to use incorrectly

### Option 3: Simply Remove the Call (Chosen ✅)
Remove `_initialize_visible_walker_paths()` from after-generation code.

**Pros**: 
- Simple and direct
- No API changes needed
- Already called in right place (_ready())
- Fixes the bug completely

**Cons**: None identified

## Conclusion

The fix is simple but critical:
- **Problem**: Clearing teleport data after generation
- **Solution**: Don't call the clearing function after generation
- **Result**: Teleport data preserved, dotted lines remain visible

This was a case where a function was being called in the wrong place:
- ✅ RIGHT: Call in `_ready()` to initialize empty structures
- ❌ WRONG: Call after generation (destroys collected data)

The fix preserves the complete walker path history, including teleport information, allowing users to see the full behavior of the dungeon generation algorithm.

---

**Status**: ✅ Fixed
**Files Changed**: 1 (`scripts/dungeon_visualizer.gd`)
**Lines Changed**: -1 line, +3 lines (comment)
**Testing**: Manual verification recommended
