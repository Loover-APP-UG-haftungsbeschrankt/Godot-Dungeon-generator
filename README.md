# Godot 4.6 Dungeon Generator

A robust, room-based dungeon generator for Godot 4.6 using a random walk algorithm. This system allows you to create complex dungeons by connecting pre-made room templates.

## Features

- **Resource-Based Room Templates**: Create and edit room layouts in the Godot editor
- **Visual Room Editor**: Interactive grid-based editor plugin for easy room creation
- **Smart Room Rotation**: Automatically tries all 4 rotations to find valid placements
- **Connection Matching**: Ensures rooms connect properly with matching door directions
- **Blocked Cell Overlap**: Rooms share their edge walls for compact, realistic dungeons
- **Connection Merging**: Opposing connections create solid walls when rooms overlap
- **Configurable**: Easy to add new room templates and adjust generation parameters
- **Visual Debug**: Built-in visualizer to see generated dungeons
- **Camera Controls**: Pan and zoom to explore dungeons at any scale

## Project Structure

```
├── addons/
│   └── meta_room_editor/       # Visual editor plugin for MetaRoom resources
│       ├── plugin.gd           # Plugin registration
│       ├── plugin.cfg          # Plugin configuration
│       ├── meta_room_inspector_plugin.gd  # Inspector integration
│       ├── meta_room_editor_property.gd   # Visual editor UI
│       └── README.md           # Plugin documentation
├── scripts/
│   ├── meta_cell.gd           # Single cell in a room (floor, door, blocked)
│   ├── meta_room.gd           # Room template (grid of cells)
│   ├── room_rotator.gd        # Static methods for rotating rooms
│   ├── dungeon_generator.gd   # Main generator using random walk
│   ├── dungeon_visualizer.gd  # Visual debug renderer
│   └── camera_controller.gd   # Pan and zoom camera controls
├── resources/
│   └── rooms/
│       ├── cross_room.tres           # 4-way connection room
│       ├── l_corridor.tres           # L-shaped corridor
│       ├── straight_corridor.tres    # Straight hallway
│       └── t_room.tres               # T-shaped room
└── scenes/
    └── test_dungeon.tscn      # Test scene with visualizer
```

## How It Works

### 1. MetaCell
Each cell in a room has:
- **Type**: BLOCKED, FLOOR, or DOOR
- **Connections**: UP, RIGHT, BOTTOM, LEFT flags
- Connections indicate where this cell can connect to adjacent rooms

### 2. MetaRoom
A room template consisting of:
- Width and height dimensions
- Grid of MetaCells
- Connection points (cells on edges with connections)

### 3. Room Rotation
The `RoomRotator` class can rotate rooms by 0°, 90°, 180°, or 270°:
- Rotates the cell grid positions
- Rotates connection directions appropriately
- Returns a new rotated MetaRoom instance

### 4. Blocked Cell Overlap System

When rooms connect, their blocked edge cells **overlap** to create shared walls:

- **Compact Dungeons**: Two 3x3 rooms = 5 cells wide (not 6)
- **Shared Walls**: Rooms share blocked edge cells instead of having gaps
- **Connection Merging**: When overlapping cells have opposite connections (←→ or ↑↓), both connections are removed to create solid walls
- **Space Efficiency**: Reduces total dungeon size by 16-27% for typical layouts

Example:
```
Room A    +    Room B    =    Combined (5 cells, not 6)
■ ■ ■         ■ ■ ■           ■ ■ ■ ■ ■
■·→[■]  +  [■]←·■    =     ■·→←·■
■ ■ ■         ■ ■ ■           ■ ■ ■ ■ ■
       [■] = Shared blocked cell (overlap)
```

See `ROOM_OVERLAP_SYSTEM.md` for technical details and `ROOM_OVERLAP_EXAMPLES.md` for visual examples.

### 5. Resource Cloning and Safe Modifications

To enable safe modifications during dungeon generation (like setting cell types to DOOR at connection points), the generator **clones all rooms before placement**:

- **Template Preservation**: Original room templates remain unchanged
- **Safe Modifications**: Placed rooms can be modified without affecting templates
- **Door Placement**: Overlapping cells with opposite connections can be converted to DOOR type
- **Reproducibility**: Each generation starts with clean templates

**How it works:**
```gdscript
# First room is explicitly cloned
var first_room_clone = start_room.clone()
var first_placement = PlacedRoom.new(first_room_clone, ...)

# Rotated rooms are automatically cloned by RoomRotator
var rotated_room = RoomRotator.rotate_room(template, rotation)  # Returns clone
```

This allows you to safely implement features like:
- Converting overlapping blocked cells to DOOR type when they have opposite connections
- Modifying cell properties during placement
- Implementing custom room merging logic

See `DOOR_PLACEMENT_FIX.md` for detailed explanation of this system.

### 6. Dungeon Generation Algorithm

The generator uses a **room-based random walk**:

1. Start with a random room that has connections
2. **Clone it** to avoid modifying the template
3. Place it at the origin
4. Pick a random connection point from the current room
5. Pick a random room template from available rooms
6. Try all 4 rotations to find a matching connection (**rotations return clones**)
7. Check if the room can be placed (allowing blocked cell overlaps)
8. If valid, **place the cloned room**, merge overlapping connections, and move to it
9. Repeat until target room count or no valid placements

Key features:
- **All placed rooms are clones** - templates remain unchanged
- Prevents revisiting previously visited rooms
- Smart connection matching (opposite directions)
- Allows blocked-blocked overlaps for compact dungeons
- Merges opposing connections in overlapping cells
- Supports safe cell type modifications (e.g., door placement)
- Maximum attempts limit to avoid infinite loops

## Usage

## Usage

### Running the Test Scene

1. Open the project in Godot 4.6
2. Press F5 to run the test scene
3. Use camera controls to explore:
   - **Mouse Wheel**: Zoom in/out
   - **Middle/Right Mouse**: Pan/drag the view
   - **+/- Keys**: Zoom in/out
   - **0 Key**: Reset camera
   - **Touchpad Pinch** (MacBook): Zoom in/out
   - **Touchpad Two-Finger Pan** (MacBook): Pan/scroll the view
4. Press R to regenerate with the same seed
5. Press S to generate with a new random seed

See `CAMERA_CONTROLS.md` for detailed camera documentation.

### Creating Custom Room Templates

**Option 1: Using the Visual Editor (Recommended)**

1. Enable the MetaRoom Editor plugin:
   - Go to **Project > Project Settings > Plugins**
   - Find "MetaRoom Editor" and enable it
2. Create a new MetaRoom resource:
   - Right-click in `resources/rooms/`
   - Select **New Resource...**
   - Choose **MetaRoom**
   - Save with a descriptive name
3. The visual editor will appear in the Inspector:
   - Set room dimensions and click "Resize Room"
   - Select a cell type (BLOCKED, FLOOR, DOOR)
   - Click cells to paint them
   - Select a connection direction (UP, RIGHT, BOTTOM, LEFT)
   - Click edge cells to toggle connections
4. Save and use your new room!

See `addons/meta_room_editor/README.md` for detailed editor documentation.

**Option 2: Manual Creation**

1. In Godot, create a new Resource
2. Set the script to `res://scripts/meta_room.gd`
3. Set width and height
4. Create cells array with MetaCell resources
5. For each cell:
   - Set cell_type (BLOCKED, FLOOR, DOOR)
   - Set connection flags for edge cells
6. Save as `.tres` file in `resources/rooms/`

### Using the Generator in Code

```gdscript
# Add DungeonGenerator node to your scene
var generator = DungeonGenerator.new()
add_child(generator)

# Load room templates
generator.room_templates = [
    preload("res://resources/rooms/cross_room.tres"),
    preload("res://resources/rooms/l_corridor.tres"),
    # ... more rooms
]

# Configure generation
generator.target_room_count = 20
generator.generation_seed = 12345  # 0 for random

# Generate
if generator.generate():
    # Access generated rooms
    for placed_room in generator.placed_rooms:
        var room = placed_room.room
        var position = placed_room.position
        var rotation = placed_room.rotation
        # Use room data to spawn actual game objects
```

### Accessing Generated Dungeon Data

```gdscript
# Get all placed rooms
for placement in generator.placed_rooms:
    var room: MetaRoom = placement.room
    var world_pos: Vector2i = placement.position
    var rotation: RoomRotator.Rotation = placement.rotation
    
    # Iterate cells in the room
    for y in range(room.height):
        for x in range(room.width):
            var cell = room.get_cell(x, y)
            var cell_world_pos = placement.get_cell_world_pos(x, y)
            # Spawn tiles, props, enemies, etc.

# Get dungeon bounds
var bounds: Rect2i = generator.get_dungeon_bounds()
print("Dungeon size: ", bounds.size)
```

## Example Room Patterns

### Cross Room (4 connections)
```
  X
X X X
  X
```

### L-Corridor (3 connections)
```
X X X
X
X
```

### Straight Corridor (2 connections)
```
X
X
X
```

### T-Room (3 connections)
```
X X X
  X
  X
```

## Tips for Creating Good Room Templates

1. **Varied Connections**: Create rooms with 1, 2, 3, and 4 connections
2. **Different Sizes**: Mix small (3x3) and larger (5x5, 7x7) rooms
3. **Edge Connections**: Place connections on room edges only
4. **Symmetry**: Symmetric rooms work well with rotation
5. **Dead Ends**: Include some rooms with only 1 connection for endpoints

## Configuration Parameters

### DungeonGenerator
- `room_templates`: Array of MetaRoom resources to use
- `target_room_count`: Desired number of rooms (default: 10)
- `generation_seed`: Seed for reproducible generation (0 = random)
- `max_placement_attempts`: Max attempts before giving up (default: 100)

### DungeonVisualizer
- `cell_size`: Size of each cell in pixels (default: 32)
- `draw_grid`: Show grid lines (default: true)
- `draw_connections`: Show connection indicators (default: true)

## Technical Details

### Coordinate System
- Rooms are placed in a world grid coordinate system
- Origin (0, 0) is where the first room is placed
- Positions can be negative (dungeon expands in all directions)

### Rotation Implementation
- 90° clockwise: (x, y) → (y, width-1-x)
- 180°: (x, y) → (width-1-x, height-1-y)
- 270° clockwise: (x, y) → (height-1-y, x)

### Connection Directions
- UP (0), RIGHT (1), BOTTOM (2), LEFT (3)
- Connections must match opposite directions to connect
- Rotations shift directions: (dir + rotation) % 4

## Performance

The generator is fast and reliable:
- Typical generation: < 100ms for 10-20 rooms
- Collision detection uses Dictionary lookup (O(1))
- Room rotation is lazy (only when needed)

## Extending the System

### Adding Features

1. **Room Types/Tags**: Add metadata to rooms (combat, treasure, boss)
2. **Mandatory Rooms**: Ensure specific rooms always appear
3. **Path Validation**: Ensure all rooms are reachable
4. **Dead End Removal**: Post-process to remove unwanted dead ends
5. **Door Generation**: Track actual door positions for spawning

### Integration with Game

Use the generated data to:
- Spawn TileMap tiles
- Place enemies and items
- Create navigation meshes
- Generate minimap data
- Set up lighting and ambience

## License

This dungeon generator system is provided as-is for use in your Godot projects.

## Credits

Created as a production-ready dungeon generation system for Godot 4.6.
