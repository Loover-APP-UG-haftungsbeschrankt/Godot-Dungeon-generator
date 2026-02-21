# Godot 4.6 Dungeon Generator

A robust, room-based dungeon generator for Godot 4.6 using a multi-walker algorithm. This system creates complex, interconnected dungeons by connecting pre-made room templates with automatic overlap handling for compact layouts.

## Features

### Core Generation
- **Multi-Walker Generation**: Multiple independent walkers simultaneously place rooms for organic layouts
- **Compactness Control**: Adjustable bias (0.0-1.0) for tighter or sprawling dungeons
- **Cell-Count Based**: Generation stops when a target cell count is reached (precise size control)
- **Smart Room Rotation**: Automatically tries all 4 rotations to find valid placements
- **Blocked Cell Overlap**: Rooms share their edge walls for compact, realistic dungeons (16-27% smaller)
- **Connection Merging**: Opposing connections create solid walls when rooms overlap
- **Resource-Based Room Templates**: Create and edit room layouts in the Godot editor
- **Configurable Parameters**: Easy to tune generation behavior

### Room Templates
- **Visual Room Editor**: Interactive grid-based editor plugin for easy room creation
- **Connection Matching**: Ensures rooms connect properly with matching door directions
- **Template Cloning**: All rooms are cloned before placement to preserve original templates
- **Consecutive Duplicate Prevention**: Same template won't be placed twice in a row by same walker

### Visualization & Debugging
- **Advanced Walker Visualization**: See walkers in action with colored markers and path trails
  - Unique colors per walker (golden ratio-based color generation)
  - Complete path history with gradient fade on older segments
  - Exact teleport detection with dotted lines
  - Return detection with different visual styling
  - Step numbers showing walker progression at every room
- **Per-Walker Path Controls**: Toggle individual walker paths on/off (keyboard 0-9 or UI checkboxes)
- **Toggle All Button**: Quickly enable/disable all walker paths at once
- **Mouse Position Display**: Real-time grid coordinates under mouse cursor
- **Step-by-Step Mode**: Watch generation happen in slow motion for debugging
- **Live Statistics**: Room count, cell count, walker count, dungeon dimensions, seed, and compactness
- **Visual Debug Renderer**: Built-in visualizer to see generated dungeons
- **Camera Controls**: Pan and zoom to explore dungeons at any scale (including touchpad gestures)

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
│   ├── dungeon_tile_renderer.gd  # Converts meta-cells to TileMap tiles
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
- **Connections**: UP, RIGHT, BOTTOM, LEFT flags indicating where this cell can connect to adjacent rooms
- **Connection Required Flag**: Boolean flag to mark a cell's connection as mandatory
  - When a room has required connections, the generator ensures all of them (except the incoming one) are satisfied
  - If not all required connections can be fulfilled, the room is not placed
  - Additional rooms are automatically placed to satisfy required connections
  - Used for rooms like T-rooms or L-corridors where all exits must connect

### 2. MetaRoom
A room template consisting of:
- Width and height dimensions
- Grid of MetaCells
- Connection points (cells on edges with connections)
- Optional room name for identification

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

### 5. POTENTIAL_PASSAGE Resolution (Post-Processing)

After meta-room generation completes, a dedicated post-processing step evaluates every remaining `POTENTIAL_PASSAGE` cell and decides whether it becomes a walkable `PASSAGE` or a solid `BLOCKED` cell.

#### How It Works

`POTENTIAL_PASSAGE` cells arise wherever two rooms share an overlapping BLOCKED cell that carries facing connections (e.g. `←` meets `→`). The walker algorithm already upgrades the connection cells it *actively traverses* to `PASSAGE`. All remaining `POTENTIAL_PASSAGE` cells are candidates for this step.

Because the walker algorithm guarantees full dungeon connectivity, every remaining `POTENTIAL_PASSAGE` group is an **optional loop shortcut**. The resolver groups them into **4-connected components** and decides each one using the **dead-end depth** of both sides:

| Case | Decision |
|------|----------|
| Component touches < 2 distinct rooms | Always `BLOCKED` — dead-end stub, no two rooms to connect |
| `depth_a >= min_loop_dead_end_depth` AND `depth_b >= min_loop_dead_end_depth` | `PASSAGE` — meaningful shortcut rescuing deep dead-end arms on both sides |
| Otherwise (trivial or shallow loop) | `BLOCKED` or `PASSAGE` with `loop_passage_chance` probability |

**Dead-end depth** for a room is the longest chain reachable from that room while traversing only rooms with degree ≤ 2 (dead-end rooms and corridors). Traversal stops when it hits a junction room (degree > 2). This directly measures how deep a player would be stuck in a dead-end arm.

**Example:** A passage connecting two dead-end corridors of 4 rooms each has depth 3 on each side. With `min_loop_dead_end_depth = 2` (default) it would be opened; with `min_loop_dead_end_depth = 4` it would not.

#### Signal

```gdscript
signal passages_resolved(opened_count: int, blocked_count: int)
```

Emitted when resolution finishes. `opened_count` and `blocked_count` are the number of passage *groups* (not individual cells) that were opened or blocked.

#### Configuration

- `min_loop_dead_end_depth` — minimum dead-end chain depth required on **both** sides to auto-open a passage (default: `2`, range: 1–10).
- `loop_passage_chance` — probability (0.0–1.0) that a **shallow/trivial** loop is opened anyway (default: `0.25`).

```gdscript
generator.min_loop_dead_end_depth = 3  # Require 4-room-deep dead ends on both sides
generator.loop_passage_chance = 0.05   # Almost never open shallow loops
```


### 6. Resource Cloning and Safe Modifications

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

### 7. Multi-Walker Dungeon Generation Algorithm

The generator uses a **multi-walker room placement algorithm** that creates more organic, interconnected dungeons:

#### How It Works:

1. **Initialization**:
   - Start with a random room that has connections
   - **Clone it** to avoid modifying the template
   - Place it at the origin (0, 0)
   - Spawn multiple walkers at the first room

2. **Walker Behavior**:
   - Each walker independently tries to place rooms from its current position
   - **Avoids consecutive duplicate templates** (prevents same template being placed twice in a row by same walker)
   - Tries up to 10 times per room (different templates/rotations)
   - If successful, moves to the newly placed room
   - If failed, teleports to a random room with open connections
   - Dies after placing its maximum number of rooms
   - When a walker dies, a new one spawns at a random room with open connections

3. **Walker Spawning**:
   - When a walker dies, a new one spawns
   - **50% chance to spawn at the dead walker's current position** (if it has open connections)
   - 50% chance to spawn at a random room with open connections
   - This creates varied dungeon layouts with both continued growth and new exploration branches

4. **Generation Loop**:
   - Each iteration, all walkers attempt to place one room
   - Continues until target cell count is reached
   - Allows loops: walkers can connect to existing rooms (reduces dead ends)
   - Safety limit prevents infinite loops

5. **Room Placement**:
   - Pick random connection from walker's current room
   - Try random template and rotation
   - Check if room can be placed (allowing blocked cell overlaps)
   - **Required Connection Validation**: If the room has required connections:
     - Identifies which connections must be satisfied (all except the incoming one)
     - Simulates placement to check if additional rooms can fulfill all requirements
     - Only places the room if all required connections can be satisfied
     - Automatically places additional rooms to fulfill requirements
   - If valid, **place the cloned room**, merge overlapping connections
   - Walker moves to the new room

#### Key Features:

- **Required Connection Validation**: Ensures rooms with mandatory connections (like T-rooms) are fully connected
- **Consecutive Duplicate Prevention**: Same template won't be placed twice in a row by the same walker
- **Multiple Simultaneous Walkers**: 3+ walkers work in parallel for varied layouts
- **Cell-Count Based**: Stops at target cell count, not room count (more precise control)
- **Automatic Loop Creation**: Walkers can connect to existing rooms naturally
- **Smart Teleportation**: Walkers jump to rooms with open connections when stuck
- **Walker Lifecycle**: Dead walkers respawn, maintaining constant exploration
- **Walker Color System**: Each walker gets a unique color using golden ratio-based color generation
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
- `compactness_bias`: How compact dungeons are (0.0 = random, 1.0 = very compact, default: 0.3)
- **`min_loop_dead_end_depth`**: Minimum dead-end depth on both sides to auto-open a loop passage (default: 2)
- **`loop_passage_chance`**: Probability to open shallow/trivial loop passages in post-processing (0.0–1.0, default: 0.25)

This algorithm creates dungeons with:
- More organic layouts (multiple growth points)
- Fewer dead ends (walkers create loops)
- Better connectivity (walkers meet and merge)
- Predictable size (cell count based, not room count)
- Unique walker paths (visible in debug visualization)

## Usage

### Running the Test Scene

1. Open the project in Godot 4.6
2. Press F5 to run the test scene
3. Use camera controls to explore:
   - **Mouse Wheel**: Zoom in/out
   - **Middle/Right Mouse**: Pan/drag the view
   - **+/- Keys**: Zoom in/out
   - **Home Key**: Reset camera (changed from 0 key to avoid conflict)
   - **Touchpad Pinch** (MacBook): Zoom in/out
   - **Touchpad Two-Finger Pan** (MacBook): Pan/scroll the view

### Generation Controls

- **R** - Regenerate dungeon with the same seed
- **S** - Generate with a new random seed

### Visualization Controls (Enhanced!)

- **W** - Toggle walker visualization on/off
- **P** - Toggle path visualization on/off
- **N** - Toggle step numbers on walker paths on/off
- **V** - Toggle step-by-step generation mode
- **C** - Increase compactness bias (+0.1)
- **X** - Decrease compactness bias (-0.1)
- **A** - Toggle all walker paths on/off
- **0-9** - Toggle visibility of individual walker paths (press walker ID number)
- **Home** - Reset camera to center (changed from 0 key)

#### Walker Visualization Features

The visualizer now shows:
- **Colored Walker Markers**: Each walker has a unique color (generated using golden ratio) and displays its ID
  - Walkers are positioned at the **center of rooms** for better visualization
  - Larger size and thicker outline for improved visibility
- **Enhanced Path Trails**: See the complete history of where each walker has been
  - **Wider path lines** (4px default, configurable via `path_line_width`)
  - Path lines connect room centers, not corners
  - **Dotted lines for teleports**: Exact detection when walker respawns to different location
  - **Thinner lines for returns**: Different visual when walker returns to previously visited room
  - Gradient fade effect on older path segments
- **Step Numbers**: Numbered markers at **every room** the walker visits
  - Shows the progression of walker movement
  - **Return indicators**: Different background color (dark red) when returning to visited room
  - Improved text centering for better readability
- **Walker Selection UI**: Graphical panel with checkboxes to toggle individual walker paths
  - Color-coded indicators for each walker
  - **"Toggle All" button**: Quickly enable/disable all walker paths at once
  - **Works during generation**: UI updates dynamically when walkers spawn/respawn
  - Syncs with keyboard shortcuts (0-9 keys)
  - Located in top-right corner
- **Mouse Position Display**: Real-time grid coordinates under mouse cursor
  - Shows meta cell position: "Cell: (x, y)"
  - Located in bottom-right corner
  - Updates continuously as mouse moves
  - Accounts for camera zoom and pan
  - Useful for debugging and navigation
- **Selective Path Visibility**: Toggle individual walker paths on/off using number keys or UI
  - Press `0` to toggle walker 0's path, `1` for walker 1, etc.
  - Click checkboxes in the Walker Path Visibility panel
  - Helps focus on specific walker behaviors
- **Live Statistics**: Active walker count, compactness bias, seed, room count, cell count, and dungeon dimensions
- **Step-by-Step Mode**: Watch the generation algorithm work in real-time

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
   
   **Simplified Inspect-Only Interface**:
   - **Click any cell** to view and edit all its properties
   - Properties panel appears showing:
     - **Cell Status**: Dropdown to select BLOCKED/FLOOR/DOOR
     - **Connections**: Checkboxes for all 4 directions (UP/RIGHT/BOTTOM/LEFT)
   - Changes apply immediately to the cell
   - **Visual Feedback**: 
     - Regular connections shown with thin arrows (↑→↓←)
     - Cell types color-coded (dark=BLOCKED, light=FLOOR, blue=DOOR)
   - **Grid Label**: "Room Grid (Click to view/edit cell properties)"
   - No mode switching needed - every click opens the properties panel

4. **Set Room Properties**: 
   - Optional: Set a descriptive `room_name` for easier identification

5. Save and use your new room!

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

### TileMap Rendering System

The `DungeonTileRenderer` automatically converts generated meta-cells into TileMap tiles for visual display.

#### How It Works

1. **Automatic Rendering**: Connects to `DungeonGenerator.generation_complete` signal
2. **Meta-Cell Expansion**: Each meta-cell becomes a 5×5 grid of tiles (configurable via `CELLS_PER_META` constant)
3. **Floor Tiles**: Non-BLOCKED cells use grass tiles from TileSet source 0 (8×8 atlas) with deterministic variation
4. **Wall Tiles**: BLOCKED cells use the solid stone tile from TileSet source 1 (atlas coord 2:3)
5. **No Manual Setup**: Just attach the script to your TileMapLayer node

#### Configuration

The renderer uses these constants (defined in the script):

```gdscript
const CELLS_PER_META: int = 5        # Each meta-cell = 5×5 tiles
const FLOOR_SOURCE_ID: int = 0       # Grass tileset (8×8 atlas, 32×32 tiles)
const WALL_SOURCE_ID: int = 1        # Wall tileset (16×16 atlas, 32×32 tiles, with physics)
const WALL_ATLAS_COORD: Vector2i = Vector2i(2, 3)  # Solid stone wall tile
const FLOOR_ATLAS_COLS: int = 8      # 8×8 grass palette (columns and rows)
```

#### Setup in Your Scene

1. Add a `TileMapLayer` node (e.g., named "Ground")
2. Configure the TileSet with your tile sources (see `test_dungeon.tscn` for example)
3. Attach `dungeon_tile_renderer.gd` script to the TileMapLayer
4. Ensure `DungeonGenerator` is at `../DungeonGenerator` relative path

The renderer will automatically:
- Clear old tiles on new generation
- Render all floor cells with grass tile variation
- Scale the dungeon for visual display (meta-cells are abstract units, tiles are visual pixels)

#### TileSet Requirements

- **Source 0** (Floor): Atlas with grass/floor tiles (no physics required)
- **Source 1** (Walls): Atlas with wall tiles and physics collision shapes

See the `test_dungeon.tscn` file for a complete working example with configured TileSet sources.

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
generator.compactness_bias = 0.3                   # 0.0-1.0, how tight the dungeon is

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
6. **Many Variations**: Create lots of room templates - walkers will try different templates randomly
7. **Balanced Pool**: Having diverse room shapes and sizes creates more interesting dungeons

## Configuration Parameters

### DungeonGenerator
- `room_templates`: Array of MetaRoom resources to use
- `num_walkers`: Number of simultaneous walkers (default: 3)
- `max_rooms_per_walker`: Max rooms each walker can place before dying (default: 20)
- `max_placement_attempts_per_room`: Max attempts to place each room (default: 10)
- `target_meta_cell_count`: Target total cell count to generate (default: 500)
- `max_iterations`: Maximum generation loop iterations for safety (default: 10000)
- `generation_seed`: Seed for reproducible generation (0 = random)
- **`compactness_bias`**: Controls how compact dungeons are (0.0 = random, 1.0 = very compact, default: 0.3)
- **`enable_visualization`**: Enable step-by-step visualization mode (default: false)
- **`visualization_step_delay`**: Delay in seconds between steps when visualizing (default: 0.1)

### MetaRoom
- `width`: Width of the room in cells
- `height`: Height of the room in cells
- `cells`: Array of MetaCell resources
- `room_name`: Identifier for this room template

### DungeonVisualizer
- `cell_size`: Size of each cell in pixels (default: 32)
- `draw_grid`: Show grid lines (default: true)
- `draw_connections`: Show connection indicators (default: true)
- **`draw_walkers`**: Show active walker markers (default: true)
- **`draw_walker_paths`**: Show walker path trails (default: true)
- **`path_line_width`**: Width of walker path lines in pixels (default: 4.0)
- **`draw_step_numbers`**: Show numbered markers at every room (default: true)
- **`draw_return_indicators`**: Highlight when walker returns to visited room (default: true)
- **`teleport_dash_length`**: Length of dashes in teleport lines (default: 10.0)
- **`teleport_gap_length`**: Length of gaps in teleport lines (default: 10.0)
- **`step_marker_radius`**: Radius of step number circle markers (default: 14.0)

**Note:** `teleport_distance_threshold` has been removed - teleport detection is now exact, not heuristic-based.

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
- Room position caching for efficient path visualization

### Performance Tips:
- Larger room templates = fewer rooms needed = faster generation
- Lower `max_placement_attempts_per_room` = faster but potentially incomplete dungeons
- Higher `compactness_bias` = tighter dungeons with less wasted placement attempts
- Visualization mode adds overhead - disable for production use

## Known Limitations

1. **Consecutive Duplicate Prevention Only**: The generator prevents the same template from being placed twice in a row by the same walker, but the same template can appear multiple times in different parts of the dungeon. This is by design to allow creating varied dungeons even with a limited template pool.

2. **No Path Validation**: The generator doesn't verify that all rooms are reachable from the starting room. Isolated room clusters can occur in rare cases with very low compactness bias or incompatible room layouts. Consider implementing flood-fill validation if your game requires guaranteed connectivity (see "Extending the System" section).

3. **No Dead-End Control**: Cannot specify desired number or placement of dead-end rooms.

4. **Fixed Cell Size**: All cells are the same size - no support for multi-cell props or variable cell dimensions.

5. **2D Only**: Currently designed for 2D dungeons only, though the system could be adapted for 3D.

6. **Sequential Walkers**: Walkers are processed sequentially in the generation loop, not in parallel threads.

7. **No Save/Load**: Generated dungeons exist only in memory during runtime. Implement your own serialization if needed.

## Troubleshooting

### Generation Fails (returns false)
- **Not enough room templates**: Add more room varieties
- **Incompatible room connections**: Ensure rooms have diverse connection patterns
- **Target cell count too high**: Reduce `target_meta_cell_count` or add larger rooms
- **Too few placement attempts**: Increase `max_placement_attempts_per_room`

### Dungeons Are Too Sprawling
- Increase `compactness_bias` (try 0.5-0.7)
- Use more rooms with multiple connections (T-rooms, cross rooms)
- Reduce `max_rooms_per_walker` to prevent long chains

### Dungeons Are Too Compact/Dense
- Decrease `compactness_bias` (try 0.1-0.2)
- Use more straight corridors and L-corridors
- Add larger room templates

### Walker Visualization Is Slow
- Disable path drawing with **P** key
- Disable step numbers with **N** key
- Reduce number of walkers
- Use larger rooms (fewer total rooms to visualize)

### Rooms Don't Connect Properly
- Check that edge cells have proper connection flags
- Verify connections are on opposite sides (UP connects to BOTTOM, LEFT to RIGHT)
- Use the visual editor to see connection arrows

## Extending the System

### Possible Extensions

1. **Room Types/Tags**: Add metadata to rooms (combat, treasure, boss)
   ```gdscript
   # Add custom properties to MetaRoom
   @export var room_type: String = "normal"  # combat, treasure, boss, etc.
   @export var difficulty: int = 1
   ```

2. **Mandatory Rooms**: Ensure specific rooms always appear
   ```gdscript
   # Place required rooms first, then let walkers fill in the rest
   var boss_room = preload("res://resources/rooms/boss_room.tres")
   generator.place_room_at(boss_room, Vector2i(0, 0))
   ```

3. **Path Validation**: Ensure all rooms are reachable (optional but recommended for games requiring guaranteed connectivity)
   ```gdscript
   # Implement flood-fill after generation to verify connectivity
   func validate_all_reachable(generator: DungeonGenerator) -> bool:
       if generator.placed_rooms.is_empty():
           return false
       
       var visited = {}
       var queue = [generator.placed_rooms[0]]
       visited[generator.placed_rooms[0]] = true
       
       while not queue.is_empty():
           var current = queue.pop_front()
           # Find connected neighbors through doors
           # Add unvisited neighbors to queue and mark as visited
           # (Implementation details depend on how you track connections)
       
       return visited.size() == generator.placed_rooms.size()
   ```

4. **Dead End Tracking**: Post-process to identify and optionally remove dead ends
   ```gdscript
   func find_dead_ends() -> Array[PlacedRoom]:
       var dead_ends = []
       for placed in generator.placed_rooms:
           if count_active_connections(placed) == 1:
               dead_ends.append(placed)
       return dead_ends
   ```

5. **Door Position Tracking**: Track exact door cell positions for spawning
   ```gdscript
   # Access overlapping connection cells
   for placed in generator.placed_rooms:
       for y in range(placed.room.height):
           for x in range(placed.room.width):
               var cell = placed.room.get_cell(x, y)
               if cell.cell_type == MetaCell.CellType.DOOR:
                   var world_pos = placed.get_cell_world_pos(x, y)
                   spawn_door(world_pos)
   ```

6. **Room Temperature System**: Track "heat" from central rooms for enemy difficulty
   ```gdscript
   # Calculate distance from start room to each placed room
   # Use for spawning stronger enemies farther from start
   ```

### Integration with Game

Use the generated data to:

```gdscript
# Example: Spawn TileMap tiles
func spawn_tilemap(generator: DungeonGenerator, tilemap: TileMap):
	for placed in generator.placed_rooms:
		for y in range(placed.room.height):
			for x in range(placed.room.width):
				var cell = placed.room.get_cell(x, y)
				var world_pos = placed.get_cell_world_pos(x, y)
				
				match cell.cell_type:
					MetaCell.CellType.FLOOR:
						tilemap.set_cell(0, world_pos, 0, Vector2i(0, 0))
					MetaCell.CellType.BLOCKED:
						tilemap.set_cell(0, world_pos, 0, Vector2i(1, 0))
					MetaCell.CellType.DOOR:
						tilemap.set_cell(0, world_pos, 0, Vector2i(2, 0))

# Example: Place enemies based on distance from start
func spawn_enemies(generator: DungeonGenerator):
	var start_pos = generator.placed_rooms[0].position
	
	for placed in generator.placed_rooms:
		var distance = start_pos.distance_to(placed.position)
		var enemy_count = int(distance / 3.0)  # More enemies farther away
		
		# Spawn enemies in floor cells
		for y in range(placed.room.height):
			for x in range(placed.room.width):
				var cell = placed.room.get_cell(x, y)
				if cell.cell_type == MetaCell.CellType.FLOOR and enemy_count > 0:
					var world_pos = placed.get_cell_world_pos(x, y)
					spawn_enemy_at(world_pos)
					enemy_count -= 1

# Example: Generate navigation mesh
func create_navigation(generator: DungeonGenerator, nav_region: NavigationRegion2D):
	var navigation_polygon = NavigationPolygon.new()
	
	# Add floor cells as walkable areas
	for placed in generator.placed_rooms:
		for y in range(placed.room.height):
			for x in range(placed.room.width):
				var cell = placed.room.get_cell(x, y)
				if cell.cell_type != MetaCell.CellType.BLOCKED:
					var world_pos = placed.get_cell_world_pos(x, y)
					# Add cell to navigation polygon
	
	nav_region.navigation_polygon = navigation_polygon

# Example: Create minimap
func generate_minimap(generator: DungeonGenerator) -> Image:
	var bounds = generator.get_dungeon_bounds()
	var image = Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGB8)
	
	for placed in generator.placed_rooms:
		for y in range(placed.room.height):
			for x in range(placed.room.width):
				var cell = placed.room.get_cell(x, y)
				var world_pos = placed.get_cell_world_pos(x, y)
				var local_pos = world_pos - bounds.position
				
				match cell.cell_type:
					MetaCell.CellType.FLOOR:
						image.set_pixel(local_pos.x, local_pos.y, Color.WHITE)
					MetaCell.CellType.BLOCKED:
						image.set_pixel(local_pos.x, local_pos.y, Color.BLACK)
					MetaCell.CellType.DOOR:
						image.set_pixel(local_pos.x, local_pos.y, Color.BLUE)
	
	return image
```

## License

This dungeon generator system is provided as-is for use in your Godot projects.

## Credits

Created as a production-ready dungeon generation system for Godot 4.6.
