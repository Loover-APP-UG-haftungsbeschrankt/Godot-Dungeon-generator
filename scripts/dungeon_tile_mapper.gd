extends TileMapLayer

## DungeonTileMapper converts generated dungeon data to TileMap tiles.
## This script takes the MetaCell data from the dungeon generator and
## renders it using proper 32x32 pixel art tiles.

@export var generator: DungeonGenerator

# Floor pattern variation constant
const FLOOR_VARIATION_PATTERN = 3

# Tile atlas coordinates for different tile types
# These correspond to positions in castle_dungeon_tileset.png
const TILE_FLOOR = Vector2i(0, 0)           # Basic floor tile
const TILE_FLOOR_DARK = Vector2i(1, 0)      # Dark floor variant
const TILE_WALL = Vector2i(2, 0)            # Full wall
const TILE_WALL_TOP = Vector2i(3, 0)        # Wall top
const TILE_WALL_BOTTOM = Vector2i(4, 0)     # Wall bottom with floor
const TILE_DOOR = Vector2i(5, 0)            # Door

# Inner corners (wall with floor cutout)
const TILE_INNER_CORNER_TL = Vector2i(0, 1)
const TILE_INNER_CORNER_TR = Vector2i(1, 1)
const TILE_INNER_CORNER_BL = Vector2i(2, 1)
const TILE_INNER_CORNER_BR = Vector2i(3, 1)

# Outer corners (floor with wall corner)
const TILE_OUTER_CORNER_TL = Vector2i(4, 1)
const TILE_OUTER_CORNER_TR = Vector2i(5, 1)
const TILE_OUTER_CORNER_BL = Vector2i(6, 1)
const TILE_OUTER_CORNER_BR = Vector2i(7, 1)

# Side walls
const TILE_WALL_LEFT = Vector2i(0, 2)
const TILE_WALL_RIGHT = Vector2i(1, 2)


func _ready() -> void:
	# Find the DungeonGenerator if not set
	if generator == null:
		generator = get_node_or_null("../DungeonGenerator")
		if generator == null:
			push_error("DungeonTileMapper: Could not find DungeonGenerator node")
			return
	
	# Connect to generation signals
	generator.generation_complete.connect(_on_generation_complete)


func _on_generation_complete() -> void:
	## Called when dungeon generation is complete.
	update_tilemap()


func update_tilemap() -> void:
	## Update the TileMap based on current dungeon state.
	# Clear existing tiles
	clear()
	
	if generator.placed_rooms.is_empty():
		return
	
	# Render each placed room
	for placed_room in generator.placed_rooms:
		_render_room(placed_room)


func _render_room(placed_room: DungeonGenerator.PlacedRoom) -> void:
	## Render a single room to the TileMap.
	var room: MetaRoom = placed_room.room
	var room_pos: Vector2i = placed_room.position
	
	# Iterate through all cells in the room
	for y in range(room.height):
		for x in range(room.width):
			var cell: MetaCell = room.get_cell(x, y)
			var world_pos = placed_room.get_cell_world_pos(x, y)
			
			# Determine which tile to use based on cell type
			var tile_coords = _get_tile_for_cell(cell, room, x, y)
			
			# Set the tile (atlas_coords, alternative_tile=0)
			if tile_coords != Vector2i(-1, -1):
				set_cell(world_pos, 0, tile_coords, 0)


func _get_tile_for_cell(cell: MetaCell, room: MetaRoom, x: int, y: int) -> Vector2i:
	## Determine which tile to use for a given cell.
	
	# Door cells
	if cell.cell_type == MetaCell.CellType.DOOR:
		return TILE_DOOR
	
	# Floor cells
	if cell.cell_type == MetaCell.CellType.FLOOR:
		# Alternate between light and dark floor for variety
		if (x + y) % FLOOR_VARIATION_PATTERN == 0:
			return TILE_FLOOR_DARK
		return TILE_FLOOR
	
	# Blocked/Wall cells
	if cell.cell_type == MetaCell.CellType.BLOCKED:
		# Check surrounding cells to determine wall type
		var has_up = y > 0 and room.get_cell(x, y - 1).cell_type != MetaCell.CellType.BLOCKED
		var has_down = y < room.height - 1 and room.get_cell(x, y + 1).cell_type != MetaCell.CellType.BLOCKED
		var has_left = x > 0 and room.get_cell(x - 1, y).cell_type != MetaCell.CellType.BLOCKED
		var has_right = x < room.width - 1 and room.get_cell(x + 1, y).cell_type != MetaCell.CellType.BLOCKED
		
		# Corner detection
		var has_up_left = x > 0 and y > 0 and room.get_cell(x - 1, y - 1).cell_type != MetaCell.CellType.BLOCKED
		var has_up_right = x < room.width - 1 and y > 0 and room.get_cell(x + 1, y - 1).cell_type != MetaCell.CellType.BLOCKED
		var has_down_left = x > 0 and y < room.height - 1 and room.get_cell(x - 1, y + 1).cell_type != MetaCell.CellType.BLOCKED
		var has_down_right = x < room.width - 1 and y < room.height - 1 and room.get_cell(x + 1, y + 1).cell_type != MetaCell.CellType.BLOCKED
		
		# Inner corners (wall with floor cutout)
		if has_down and has_right and not has_up and not has_left:
			return TILE_INNER_CORNER_TL
		if has_down and has_left and not has_up and not has_right:
			return TILE_INNER_CORNER_TR
		if has_up and has_right and not has_down and not has_left:
			return TILE_INNER_CORNER_BL
		if has_up and has_left and not has_down and not has_right:
			return TILE_INNER_CORNER_BR
		
		# Outer corners (floor with wall corner) - when diagonal is open
		if not has_up and not has_left and has_up_left and has_down and has_right:
			return TILE_OUTER_CORNER_TL
		if not has_up and not has_right and has_up_right and has_down and has_left:
			return TILE_OUTER_CORNER_TR
		if not has_down and not has_left and has_down_left and has_up and has_right:
			return TILE_OUTER_CORNER_BL
		if not has_down and not has_right and has_down_right and has_up and has_left:
			return TILE_OUTER_CORNER_BR
		
		# Side walls
		if has_right and not has_left:
			return TILE_WALL_LEFT
		if has_left and not has_right:
			return TILE_WALL_RIGHT
		
		# Top and bottom walls
		if has_down and not has_up:
			return TILE_WALL_TOP
		if has_up and not has_down:
			return TILE_WALL_BOTTOM
		
		# Default to full wall
		return TILE_WALL
	
	# Unknown cell type, don't render
	return Vector2i(-1, -1)
