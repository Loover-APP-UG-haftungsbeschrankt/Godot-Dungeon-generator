# Getting Started with Godot 4.6 Dungeon Generator

## Quick Start (5 minutes)

### 1. Open the Project
```bash
# Option 1: Using Godot Editor
godot project.godot

# Option 2: From Godot Project Manager
Add Project > Navigate to project folder > Import & Edit
```

### 2. Run the Test Scene
- Press **F5** or click the Play button
- You'll see a generated dungeon visualized on screen
- Press **R** to regenerate with the same seed
- Press **S** to generate with a new random seed

### 3. Run Automated Tests (Optional)
- File > Open Scene > `scenes/test_system.tscn`
- Press **F5**
- Check console output for test results
- All tests should pass ✅

## Project Structure

```
Godot-Dungeon-generator/
├── 📄 README.md                    ← Start here for overview
├── 📄 DOCUMENTATION.md             ← Technical details
├── 📄 QUICK_REFERENCE.md           ← Code snippets
├── 📄 FINAL_SUMMARY.md             ← Project summary
│
├── 🎮 project.godot                ← Godot project file
│
├── 📁 scripts/                     ← All GDScript files
│   ├── meta_cell.gd                  • Cell resource
│   ├── meta_room.gd                  • Room resource
│   ├── room_rotator.gd               • Rotation logic
│   ├── dungeon_generator.gd          • Main generator
│   ├── dungeon_visualizer.gd         • Visual debug
│   └── test_system.gd                • Test suite
│
├── 📁 resources/rooms/             ← Room templates
│   ├── cross_room.tres               • 4-way room
│   ├── l_corridor.tres               • L-shaped
│   ├── straight_corridor.tres        • Straight hall
│   └── t_room.tres                   • T-shaped
│
└── 📁 scenes/                      ← Test scenes
    ├── test_dungeon.tscn             • Visual test
    └── test_system.tscn              • Automated tests
```

## Using in Your Project

### Method 1: Copy Everything
1. Copy the entire `scripts/` and `resources/` folders to your project
2. Copy the room templates you want
3. Create a DungeonGenerator node in your scene
4. Load room templates and generate!

### Method 2: Use as Plugin
1. Copy `scripts/` to `addons/dungeon_generator/`
2. Create plugin.cfg
3. Enable in Project Settings

### Method 3: Scene Instance
1. Copy `scripts/` and `resources/` to your project
2. Instance `test_dungeon.tscn` in your scene
3. Modify as needed

## Basic Usage

### 1. Create a Generator Node
```gdscript
# In your scene script
extends Node2D

var generator: DungeonGenerator

func _ready():
    # Create generator
    generator = DungeonGenerator.new()
    add_child(generator)
    
    # Load room templates
    generator.room_templates = [
        load("res://resources/rooms/cross_room.tres"),
        load("res://resources/rooms/l_corridor.tres"),
        load("res://resources/rooms/straight_corridor.tres"),
        load("res://resources/rooms/t_room.tres")
    ]
    
    # Configure
    generator.target_room_count = 15
    generator.generation_seed = 0  # Random seed
    
    # Generate
    if generator.generate():
        spawn_dungeon()
```

### 2. Spawn the Dungeon
```gdscript
func spawn_dungeon():
    for placement in generator.placed_rooms:
        spawn_room_tiles(placement)
        spawn_room_objects(placement)

func spawn_room_tiles(placement: DungeonGenerator.PlacedRoom):
    var tilemap = $TileMap
    
    for y in range(placement.room.height):
        for x in range(placement.room.width):
            var cell = placement.room.get_cell(x, y)
            if cell == null:
                continue
            
            var world_pos = placement.get_cell_world_pos(x, y)
            
            # Spawn floor tile
            if cell.cell_type == MetaCell.CellType.FLOOR:
                tilemap.set_cell(0, world_pos, 0, Vector2i.ZERO)
            
            # Spawn door
            elif cell.cell_type == MetaCell.CellType.DOOR:
                tilemap.set_cell(0, world_pos, 1, Vector2i.ZERO)
```

## Creating Custom Rooms

### In Godot Editor (Recommended)

1. **Create New Resource**
   - Right-click in FileSystem
   - New Resource
   - Search for "MetaRoom"
   - Save as `.tres` in `resources/rooms/`

2. **Configure Room**
   - Set Width and Height (e.g., 3x3)
   - Set Room Name
   - Create Cells array

3. **Add Cells**
   - For each cell (width × height):
     - Create new MetaCell resource
     - Set cell_type (BLOCKED, FLOOR, DOOR)
     - For edge cells, set connections:
       - Top row: connection_up
       - Bottom row: connection_bottom
       - Left column: connection_left
       - Right column: connection_right

4. **Test It**
   - Add your room to test_dungeon.tscn
   - Run and test!

### Programmatically

```gdscript
func create_custom_room() -> MetaRoom:
    var room = MetaRoom.new()
    room.width = 3
    room.height = 3
    room.room_name = "My Custom Room"
    
    # Create cells (3x3 = 9 cells)
    for y in range(3):
        for x in range(3):
            var cell = MetaCell.new()
            
            # Center is floor, edges are blocked
            if x == 1 and y == 1:
                cell.cell_type = MetaCell.CellType.FLOOR
            else:
                cell.cell_type = MetaCell.CellType.BLOCKED
            
            room.cells.append(cell)
    
    # Add connection at top
    room.get_cell(1, 0).cell_type = MetaCell.CellType.FLOOR
    room.get_cell(1, 0).connection_up = true
    
    # Add connection at bottom
    room.get_cell(1, 2).cell_type = MetaCell.CellType.FLOOR
    room.get_cell(1, 2).connection_bottom = true
    
    return room
```

## Configuration Options

### DungeonGenerator Settings

```gdscript
generator.room_templates = [...]     # Array of MetaRoom resources
generator.target_room_count = 15     # How many rooms to generate
generator.generation_seed = 12345    # 0 = random, else deterministic
generator.max_placement_attempts = 100  # Safety limit
```

### DungeonVisualizer Settings

```gdscript
visualizer.cell_size = 32            # Pixels per cell
visualizer.draw_grid = true          # Show grid lines
visualizer.draw_connections = true   # Show connection indicators
```

## Common Patterns

### Load All Rooms from Folder
```gdscript
func load_all_rooms() -> Array[MetaRoom]:
    var rooms: Array[MetaRoom] = []
    var dir = DirAccess.open("res://resources/rooms/")
    
    if dir:
        dir.list_dir_begin()
        var file = dir.get_next()
        while file != "":
            if file.ends_with(".tres"):
                var room = load("res://resources/rooms/" + file)
                if room is MetaRoom:
                    rooms.append(room)
            file = dir.get_next()
    
    return rooms
```

### Regenerate on Button Press
```gdscript
func _on_regenerate_button_pressed():
    generator.clear_dungeon()
    generator.generation_seed = 0  # New random seed
    
    if generator.generate():
        clear_old_dungeon()
        spawn_new_dungeon()
```

### Get Room at World Position
```gdscript
func get_room_at_position(world_pos: Vector2i) -> DungeonGenerator.PlacedRoom:
    if generator.occupied_cells.has(world_pos):
        return generator.occupied_cells[world_pos]
    return null
```

## Tips & Best Practices

### Room Design
1. **Start simple**: Begin with 3x3 rooms
2. **Vary connections**: Create rooms with 1, 2, 3, and 4 connections
3. **Use blocked cells**: Create interesting shapes with blocked cells
4. **Test rotations**: Your room will be rotated, design accordingly

### Generation
1. **More variety = better generation**: More room types = more successful placements
2. **Balance connections**: Mix high-connection (3-4) and low-connection (1-2) rooms
3. **Start small**: Test with 10-15 rooms, then increase
4. **Use seeds**: Use fixed seeds during development for reproducibility

### Performance
1. **Cache rotations**: If using same templates repeatedly
2. **Generate off-thread**: For large dungeons (50+ rooms)
3. **Limit attempts**: Adjust max_placement_attempts based on room variety
4. **Pool rooms**: Create different room pools for different areas

## Troubleshooting

### "Generation failed or incomplete"
- **Cause**: Not enough room variety or incompatible connections
- **Solution**: Add more room templates, especially with 3-4 connections

### "No rooms with connections found"
- **Cause**: All room templates are missing connections
- **Solution**: Ensure at least one edge cell has connection flags

### Rooms overlap
- **Cause**: Bug in room template dimensions
- **Solution**: Verify width × height = cells.size()

### Generation is slow
- **Cause**: Too many placement attempts
- **Solution**: Reduce target_room_count or add more room variety

## Next Steps

1. **Explore Examples**: Study the 4 example room templates
2. **Create Custom Rooms**: Design rooms for your game
3. **Integrate Gameplay**: Add enemies, items, objectives
4. **Extend System**: Add room types, special rules, etc.
5. **Read Docs**: Check DOCUMENTATION.md for advanced features

## Need Help?

1. **README.md** - Features and overview
2. **DOCUMENTATION.md** - Complete technical reference
3. **QUICK_REFERENCE.md** - Code snippets and patterns
4. **Test Scenes** - Working examples to study

## System Requirements

- **Godot**: 4.3+ (tested on 4.6)
- **Operating System**: Windows, Linux, macOS
- **Skills Needed**: Basic GDScript knowledge

## License

This dungeon generator is provided as-is for use in your Godot projects.

---

**Ready to generate dungeons? Open Godot and press F5!** 🎮✨
