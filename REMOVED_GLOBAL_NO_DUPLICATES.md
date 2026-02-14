# Feature Removed: Global "No Duplicates" Constraint

## User Request

"The Global 'No duplicates' I don't want. The dungeon generation should use the same room multiple times"

## Changes Made

### Removed Global Constraint

The global "no duplicates" constraint has been removed. Room templates can now be reused multiple times throughout the dungeon.

### Kept Local Constraint

The local constraint remains in place: **A walker cannot place the same room template it's currently in as the next room.** This prevents repetitive consecutive placement by individual walkers while allowing templates to be reused globally.

## Implementation

### What Was Removed

1. **`used_room_templates` Array**
   - Removed the global tracking array that prevented template reuse
   
2. **Global Checks in Template Selection**
   - Removed check: `if used_room_templates.has(template)`
   - Now only checks: `if template == walker.current_room.original_template`

3. **Template Marking as Used**
   - Removed: `used_room_templates.append(template)` when placing rooms
   
4. **Clear Operation**
   - Removed: `used_room_templates.clear()` from `clear_dungeon()`

5. **Exhaustion Messages**
   - Updated messages to reflect that templates are reusable
   - Changed "templates exhausted" to "no valid placements possible"

### What Was Kept

**Local "No Consecutive Same" Constraint** (Per Walker):
```gdscript
# In _walker_try_place_room()
for template in room_templates:
    # Skip if template is same as walker's current room
    if template == walker.current_room.original_template:
        continue
    available_templates.append(template)
```

This ensures walkers still create varied paths without placing the same template consecutively.

## Behavior

### Before Change
- **Global Constraint**: Each template could only be used once in entire dungeon
- **Local Constraint**: Walker couldn't place same template as current room
- **Result**: Limited to number of templates (e.g., 6 templates = max 6 rooms)

### After Change
- **Global Constraint**: REMOVED - Templates can be reused unlimited times
- **Local Constraint**: KEPT - Walker still can't place same template consecutively
- **Result**: Can generate dungeons of any size with any number of templates

## Examples

### Example 1: Small Template Set, Large Dungeon
```
Templates: [Cross, L-Corridor, T-Room]
Target: 500 cells (many rooms)

Before: Could only place 3 rooms (one of each), then stop
After:  Can place 20+ rooms, reusing templates throughout
```

### Example 2: Walker Path with Reuse
```
Walker path:
Cross → L-Corridor → Cross → T-Room → Cross → L-Corridor

Note: Cross appears 3 times, L-Corridor appears 2 times
But walker never places same template consecutively
```

### Example 3: Multiple Walkers
```
Walker A: Cross → L-Corridor → T-Room → Cross
Walker B: L-Corridor → Cross → L-Corridor → T-Room

Both can reuse all templates freely
Only restriction: can't place current template next
```

## Benefits

### 1. Unlimited Dungeon Size
No longer limited by number of unique templates:
- 3 templates can create 100+ room dungeon
- No artificial size restrictions

### 2. Natural Variety
Local constraint ensures variety without global restriction:
- Walkers create varied paths (no consecutive same)
- Templates distributed naturally throughout dungeon

### 3. Flexible Template Library
Can use fewer templates effectively:
- Don't need 50+ templates for large dungeons
- Focus on quality over quantity

### 4. Realistic Dungeons
Real dungeons often repeat room types:
- Multiple corridors of same type
- Several similar chambers
- Recurring structural patterns

## Edge Cases

### Case 1: Single Template
```
Templates: [Cross]
Walker at Cross

Available: None (Cross is current room)
Result: Walker cannot place, may die or teleport

Note: Need at least 2 templates for continuous generation
```

### Case 2: Two Templates
```
Templates: [A, B]
Walker at A → places B → at B → places A → at A → places B...

Works perfectly, alternating between templates
```

### Case 3: Many Templates
```
Templates: [A, B, C, D, E, F, G, H, I, J]
Walker at A

Available: B, C, D, E, F, G, H, I, J (all except A)
Lots of variety, natural distribution
```

## Early Termination

The early termination logic still works correctly:

**Before**: Stopped when all templates used globally
**After**: Stops when no walker can place any room (no valid connections or spatial constraints)

```gdscript
if failed_placement_streak >= num_walkers:
    print("DungeonGenerator: No valid room placements possible. Stopping generation.")
    break
```

This happens when:
- No open connections available
- No spatial room for placement
- All walkers stuck simultaneously

## Console Output

### Successful Generation
```
DungeonGenerator: Generated 25 rooms with 532 cells
```

### Early Termination (No Valid Placements)
```
DungeonGenerator: No valid room placements possible. Stopping generation.
  Templates available: 6
  Rooms placed: 18
DungeonGenerator: Generated 18 rooms with 385 cells
```

## Files Modified

**scripts/dungeon_generator.gd**:
- Line 80-81: Removed `used_room_templates` array declaration
- Line 125-126: Removed marking first room as used
- Lines 238-246: Removed global template check, kept only local constraint
- Line 286: Removed marking template as used when placing
- Lines 180-188: Updated early termination messages
- Line 575: Removed `used_room_templates.clear()`

## Migration Notes

### For Users
No action required - existing configurations work better now:
- Dungeons can grow larger with same template count
- More natural distribution of room types
- Still maintains variety through local constraint

### For Developers
If you customized the generation logic:
- `used_room_templates` array no longer exists
- Check for local constraint instead: `walker.current_room.original_template`
- Early termination based on failed placements, not template exhaustion

## Testing

### Recommended Tests
1. Generate with 3 templates, target 500 cells
   - Should complete successfully with template reuse
   
2. Generate with 2 templates, observe alternation
   - Templates should alternate naturally
   
3. Generate with 10 templates, check distribution
   - All templates should appear multiple times

### Expected Behavior
- Dungeons complete to target cell count
- Templates appear multiple times
- No consecutive same templates from same walker
- Natural variety maintained

## Summary

✅ **Removed**: Global "no duplicates" constraint
✅ **Kept**: Local "no consecutive same" constraint  
✅ **Result**: Templates can be reused unlimited times while maintaining variety

The dungeon generator now allows room templates to be used multiple times throughout the dungeon, creating larger and more natural dungeons while still preventing monotonous consecutive placement by individual walkers.
