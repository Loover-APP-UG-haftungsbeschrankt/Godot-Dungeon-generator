# Feature: Prevent Walker from Placing Same Template Consecutively

## Clarification

The requirement was misunderstood initially. The correct requirement is:

**A walker cannot place the same room template that it's currently standing in as the next room.**

This is different from the global "no duplicates" rule. It's a local constraint on each walker.

## Implementation

### Changes Made

1. **PlacedRoom Class Enhancement**
   - Added `original_template` field to track which template the room was created from
   - Updated constructor to accept and store the original template reference

```gdscript
class PlacedRoom:
    var original_template: MetaRoom  # Reference to original template
    
    func _init(p_room, p_position, p_rotation, p_original_template):
        original_template = p_original_template
```

2. **Template Filtering in _walker_try_place_room()**
   - Added filter to exclude walker's current room template from available templates
   - This prevents consecutive placement of the same template by the same walker

```gdscript
for template in room_templates:
    # Skip if template already used globally
    if used_room_templates.has(template):
        continue
    # Skip if template is same as walker's current room
    if template == walker.current_room.original_template:
        continue
    available_templates.append(template)
```

3. **Updated Function Signatures**
   - Modified `_try_connect_room()` to accept `original_template` parameter
   - Updated all calls to pass the original template reference

## Behavior

### Before
- Walker in room X could place another room X immediately adjacent
- Led to repetitive patterns with same room types next to each other

### After
- Walker in room X must place a different room type (Y, Z, etc.) as next room
- Walker can place room X again after moving to a different room
- Different walkers can still place room X in parallel

## Examples

### Scenario 1: Single Walker
```
Walker at Cross Room → can place: L-Corridor, T-Room, Straight (NOT Cross Room)
Walker moves to L-Corridor → can place: Cross Room, T-Room, Straight (NOT L-Corridor)
```

### Scenario 2: Multiple Walkers
```
Walker A at Cross Room → cannot place Cross Room
Walker B at L-Corridor → CAN place Cross Room (different current room)
```

### Scenario 3: After Moving
```
Walker at Cross Room → places T-Room → moves to T-Room
Now at T-Room → CAN place Cross Room (no longer in Cross Room)
```

## Global vs Local Constraints

The system now has TWO independent constraints:

1. **Global "No Duplicates"** (existing):
   - Each template can only be used ONCE in entire dungeon
   - Tracked via `used_room_templates` array
   - Once template X is placed anywhere, nobody can place it again

2. **Local "No Consecutive Same"** (new):
   - Walker cannot place same template as current room
   - Only applies to the walker's immediate next placement
   - Same walker can place template again later if it moves

## Edge Cases Handled

### All Templates Except Current Used
If all templates are used globally EXCEPT the walker's current room:
- `available_templates` will be empty after filtering
- Walker cannot place any room
- Generation continues with other walkers or terminates

### Walker at Last Available Template
If walker is in the last globally unused template:
- That template is filtered out for this walker
- No templates available for this walker
- Walker may teleport or die, other walkers may continue

### First Room
The first room's template is:
- Stored in `PlacedRoom.original_template`
- All walkers start from first room
- All walkers initially exclude first room's template

## Files Modified

- `scripts/dungeon_generator.gd`:
  - Line 13: Added `original_template` field to PlacedRoom
  - Line 15: Updated PlacedRoom constructor
  - Line 130: Pass template when creating first room
  - Line 228: Pass template in _try_place_next_room
  - Line 253: Filter out current template in _walker_try_place_room
  - Line 286: Pass template in walker placement
  - Line 405: Updated _try_connect_room signature
  - Line 425: Pass template when creating PlacedRoom

## Testing

### Manual Testing Required
Since Godot is not available in this environment:

1. Run the project in Godot 4.6
2. Generate dungeons with 6 room templates
3. Observe that adjacent rooms are different types
4. Verify no walker places same room type twice in a row

### Expected Behavior
- More variety in room sequences
- No consecutive duplicate room types from same walker
- Still respects global "no duplicates" rule

## Benefits

1. **More Varied Dungeons**: Prevents repetitive patterns
2. **Better Distribution**: Forces variety in room placement
3. **Natural Flow**: Creates more interesting exploration paths
4. **Backwards Compatible**: Works with existing global constraint

## Considerations

### Template Count
With both constraints active, walkers may get stuck sooner:
- Need at least 2 templates for any walker to place a room
- With 6 templates total, effective limit is 6 rooms
- Current template filtering reduces options by 1 per walker

### Performance
Minimal impact:
- One additional comparison per template
- O(1) lookup on walker's current template
- No significant performance degradation

## Summary

This change ensures walkers create more varied dungeon layouts by preventing them from placing the same room template consecutively, while still maintaining the global uniqueness constraint.
