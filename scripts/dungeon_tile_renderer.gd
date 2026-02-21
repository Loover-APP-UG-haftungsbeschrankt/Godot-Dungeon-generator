class_name DungeonTileRenderer
extends TileMapLayer

## DungeonTileRenderer converts meta-cells from the DungeonGenerator into actual TileMap tiles.
## Each meta-cell is expanded into a 5x5 grid of tiles.
## Floor cells use grass tiles from source 0, walls use solid stone tiles from source 1.

## Number of TileMap tiles per meta-cell dimension (5x5 = 25 tiles per meta-cell)
const CELLS_PER_META: int = 5

## TileSet source ID for floor/grass tiles (256x256, 8x8 atlas)
const FLOOR_SOURCE_ID: int = 0

## TileSet source ID for wall tiles (512x512, 16x16 atlas with physics)
const WALL_SOURCE_ID: int = 1

## Atlas coordinate for wall tiles - solid stone wall at (2,3)
const WALL_ATLAS_COORD: Vector2i = Vector2i(2, 3)

## Atlas size for floor tiles (8x8 grass palette)
const FLOOR_ATLAS_SIZE: int = 8

## Reference to the DungeonGenerator node
var dungeon_generator: Node = null


func _ready() -> void:
	# Connect to the DungeonGenerator
	dungeon_generator = get_node_or_null("../DungeonGenerator")
	
	if dungeon_generator == null:
		push_error("DungeonTileRenderer: Could not find DungeonGenerator node")
		return
	
	if not dungeon_generator.has_signal("generation_complete"):
		push_error("DungeonTileRenderer: DungeonGenerator does not have generation_complete signal")
		return
	
	# Connect to the generation_complete signal
	dungeon_generator.generation_complete.connect(_on_generation_complete)


## Called when dungeon generation completes
func _on_generation_complete(success: bool, room_count: int, cell_count: int) -> void:
	if not success:
		push_warning("DungeonTileRenderer: Generation failed, not rendering tiles")
		return
	
	# Clear existing tiles and render the new dungeon
	clear()
	_render_dungeon()


## Renders the entire dungeon by converting meta-cells to tiles
func _render_dungeon() -> void:
	if dungeon_generator == null:
		return
	
	# Build a dictionary of world positions -> is_floor (true = floor, false = wall)
	var tile_map: Dictionary = {}
	
	# Get placed_rooms from the generator
	var placed_rooms: Array = dungeon_generator.placed_rooms
	
	if placed_rooms.is_empty():
		push_warning("DungeonTileRenderer: No placed rooms to render")
		return
	
	# First pass: mark all floor cells
	for placement in placed_rooms:
		var meta_room = placement.room
		
		for y in range(meta_room.height):
			for x in range(meta_room.width):
				var cell = meta_room.get_cell(x, y)
				
				# Skip blocked cells (they don't get rendered)
				if cell == null or cell.cell_type == MetaCell.CellType.BLOCKED:
					continue
				
				# Get world position for this meta-cell
				var world_pos: Vector2i = placement.get_cell_world_pos(x, y)
				
				# Mark this meta-cell position as floor
				tile_map[world_pos] = true
	
	# Second pass: expand meta-cells into tiles and render
	for meta_pos in tile_map.keys():
		var is_floor: bool = tile_map[meta_pos]
		
		# Each meta-cell becomes CELLS_PER_META x CELLS_PER_META tiles
		for dy in range(CELLS_PER_META):
			for dx in range(CELLS_PER_META):
				var tile_pos: Vector2i = meta_pos * CELLS_PER_META + Vector2i(dx, dy)
				
				if is_floor:
					# Floor tile: use grass atlas with deterministic variation
					var atlas_coord: Vector2i = _get_floor_atlas_coord(tile_pos)
					set_cell(tile_pos, FLOOR_SOURCE_ID, atlas_coord)
				else:
					# Wall tile: use solid stone wall
					set_cell(tile_pos, WALL_SOURCE_ID, WALL_ATLAS_COORD)
	
	print("DungeonTileRenderer: Rendered ", tile_map.size(), " meta-cells")


## Returns a grass tile atlas coordinate based on tile position for deterministic variation
func _get_floor_atlas_coord(tile_pos: Vector2i) -> Vector2i:
	# Use position sum for simple deterministic variation across the 8x8 grass palette
	var index: int = (tile_pos.x + tile_pos.y) % (FLOOR_ATLAS_SIZE * FLOOR_ATLAS_SIZE)
	var atlas_x: int = index % FLOOR_ATLAS_SIZE
	var atlas_y: int = index / FLOOR_ATLAS_SIZE
	return Vector2i(atlas_x, atlas_y)
