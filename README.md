# Godot 4.6 Dungeon Generator

A robust, room-based dungeon generator for Godot 4.6 using a multi-walker algorithm. This system allows you to create complex, interconnected dungeons with loops by connecting pre-made room templates.

## Features

- **Multi-Walker Generation**: Multiple independent walkers simultaneously place rooms
- **Walker Visualization**: See walkers in action with colored markers and path trails
- **Compactness Control**: Adjustable bias for tighter, less sprawling dungeons
- **Step-by-Step Mode**: Watch generation happen in slow motion for debugging
- **Unique Room Placement**: Each room template can only be placed once (no duplicates)
- **Required Connections**: Rooms can specify connections that MUST be connected (e.g., T-rooms need all 3 connections used)
- **Smart Walker Spawning**: New walkers spawn at current position or rooms with unsatisfied required connections
- **Interconnected Dungeons**: Walkers create loops by connecting to existing rooms
- **Cell-Count Based**: Generation stops when a target cell count is reached (not just room count)
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
- **Required Connections**: Array of directions that MUST be connected to other rooms
  - Example: A T-room with 3 connections should have `required_connections = [UP, LEFT, RIGHT]`
  - Ensures rooms make logical sense (no T-rooms with only 1 connection used)
  - Generator prefers placing rooms near those with unsatisfied required connections

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

### 6. Multi-Walker Dungeon Generation Algorithm

The generator uses a **multi-walker room placement algorithm** that creates more organic, interconnected dungeons:

#### How It Works:

1. **Initialization**:
   - Start with a random room that has connections
   - **Clone it** to avoid modifying the template
   - Mark it as used (no duplicates allowed)
   - Place it at the origin (0, 0)
   - Spawn multiple walkers at the first room

2. **Walker Behavior**:
   - Each walker independently tries to place rooms from its current position
   - **Only tries unused room templates** (each template can only be placed once)
   - Tries up to 10 times per room (different unused templates/rotations)
   - If successful, marks template as used, moves to the newly placed room
   - If failed, teleports to a random room with open connections
   - Dies after placing its maximum number of rooms
   - When a walker dies, a new one spawns at a random room with open connections

3. **Walker Spawning**:
   - When a walker dies, a new one spawns
   - **50% chance to spawn at the dead walker's current position** (if it has open connections)
   - 50% chance to spawn at a random room with open connections
   - **Prefers rooms with unsatisfied required connections** (70% of the time)
   - This ensures rooms with required connections get properly connected

4. **Generation Loop**:
   - Each iteration, all walkers attempt to place one room
   - Continues until target cell count is reached
   - Allows loops: walkers can connect to existing rooms (reduces dead ends)
   - Safety limit prevents infinite loops

5. **Room Placement**:
   - Pick random connection from walker's current room
   - Try random unused template and rotation
   - Check if room can be placed (allowing blocked cell overlaps)
   - If valid, **place the cloned room**, mark template as used, merge overlapping connections
   - Track which connections got connected for required connection validation
   - Walker moves to the new room

#### Key Features:

- **No Duplicate Rooms**: Each room template can only be placed once
- **Required Connections**: Rooms can specify connections that MUST be used
- **Smart Walker Spawning**: Prioritizes rooms with unsatisfied required connections
- **Multiple Simultaneous Walkers**: 3+ walkers work in parallel for varied layouts
- **Cell-Count Based**: Stops at target cell count, not room count (more precise control)
- **Automatic Loop Creation**: Walkers can connect to existing rooms naturally
- **Smart Teleportation**: Walkers jump to rooms with open connections when stuck
- **Walker Lifecycle**: Dead walkers respawn, maintaining constant exploration
- **All placed rooms are clones**: Templates remain unchanged
- **Smart connection matching**: Opposite directions must match
- **Blocked cell overlap**: Compact dungeons with shared walls
- **Connection merging**: Opposing connections create solid walls or doors
- **Safe cell modifications**: Support for dynamic door placement

#### Configuration Parameters:

- `num_walkers`: Number of simultaneous walkers (default: 3)
- `max_rooms_per_walker`: Max rooms each walker places before dying (default: 20)
- `max_placement_attempts_per_room`: Tries per room placement (default: 10)
- `target_meta_cell_count`: Stop when this many cells are placed (default: 500)

This algorithm creates dungeons with:
- More organic layouts (multiple growth points)
- Fewer dead ends (walkers create loops)
- Better connectivity (walkers meet and merge)
- Predictable size (cell count based, not room count)

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

### Generation Controls

- **R** - Regenerate dungeon with the same seed
- **S** - Generate with a new random seed

### Visualization Controls (NEW!)

- **W** - Toggle walker visualization on/off
- **P** - Toggle path visualization on/off
- **V** - Toggle step-by-step generation mode
- **C** - Increase compactness bias (+0.1)
- **X** - Decrease compactness bias (-0.1)

#### Walker Visualization Features

The visualizer now shows:
- **Colored Walker Markers**: Each walker has a unique color and displays its ID
- **Path Trails**: See the complete history of where each walker has been
- **Live Statistics**: Active walker count, compactness bias, and more
- **Step-by-Step Mode**: Watch the generation algorithm work in real-time

See `WALKER_VISUALIZATION.md` for detailed documentation on the visualization system.

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
   - **Set Required Connections**: Specify which connections MUST be connected
     - For a T-room, set required_connections to [UP, LEFT, RIGHT]
     - For a cross room, set required_connections to [UP, RIGHT, BOTTOM, LEFT]
     - Leave empty for rooms where any connection is optional
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
6. **Set required_connections array**: Add MetaCell.Direction values for required connections
7. Save as `.tres` file in `resources/rooms/`

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

# Configure multi-walker generation
generator.num_walkers = 3                          # Number of simultaneous walkers
generator.max_rooms_per_walker = 20                # Max rooms per walker before death
generator.max_placement_attempts_per_room = 10     # Tries per room placement
generator.target_meta_cell_count = 500             # Stop at this many cells
generator.generation_seed = 12345                  # 0 for random

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
6. **Required Connections**: Set required_connections for rooms that need specific connections
   - T-rooms should require all 3 connections: `[UP, LEFT, RIGHT]`
   - Cross rooms should require all 4: `[UP, RIGHT, BOTTOM, LEFT]`
   - L-corridors can have no required connections (flexible usage)
   - Straight corridors can require both ends: `[UP, BOTTOM]` or `[LEFT, RIGHT]`
7. **Unique Rooms**: Remember each template can only be placed once - create many variations!

## Configuration Parameters

### DungeonGenerator
- `room_templates`: Array of MetaRoom resources to use (each can only be placed once)
- `num_walkers`: Number of simultaneous walkers (default: 3)
- `max_rooms_per_walker`: Max rooms each walker can place before dying (default: 20)
- `max_placement_attempts_per_room`: Max attempts to place each room (default: 10)
- `target_meta_cell_count`: Target total cell count to generate (default: 500)
- `max_iterations`: Maximum generation loop iterations for safety (default: 10000)
- `generation_seed`: Seed for reproducible generation (0 = random)
- **`compactness_bias`**: Controls how compact dungeons are (0.0 = random, 1.0 = very compact, default: 0.3) **(NEW!)**
- **`enable_visualization`**: Enable step-by-step visualization mode (default: false) **(NEW!)**
- **`visualization_step_delay`**: Delay in seconds between steps when visualizing (default: 0.1) **(NEW!)**

### MetaRoom
- `width`: Width of the room in cells
- `height`: Height of the room in cells
- `cells`: Array of MetaCell resources
- `room_name`: Identifier for this room template
- `required_connections`: Array of MetaCell.Direction values that MUST be connected (new!)

### DungeonVisualizer
- `cell_size`: Size of each cell in pixels (default: 32)
- `draw_grid`: Show grid lines (default: true)
- `draw_connections`: Show connection indicators (default: true)
- **`draw_walkers`**: Show active walker markers (default: true) **(NEW!)**
- **`draw_walker_paths`**: Show walker path trails (default: true) **(NEW!)**

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
- Typical generation: < 200ms for 500 cells (~15-25 rooms depending on size)
- Collision detection uses Dictionary lookup (O(1))
- Room rotation is lazy (only when needed)
- Multiple walkers work in sequence (not parallel threads)

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
