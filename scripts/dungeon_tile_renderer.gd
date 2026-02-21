class_name DungeonTileRenderer
extends TileMapLayer

## DungeonTileRenderer converts meta-cells from the DungeonGenerator into actual TileMap tiles.
## Each meta-cell expands into CELLS_PER_META x CELLS_PER_META tiles.
## FLOOR/PASSAGE meta-cells → grass tiles (source 0).
## BLOCKED meta-cells → solid stone wall tiles (source 1).

## Number of TileMap tiles per meta-cell dimension (5 x 5 = 25 tiles per meta-cell)
const CELLS_PER_META: int = 5

## TileSet source ID for floor/grass tiles (TX Tileset Grass, 8x8 atlas, source 0)
const FLOOR_SOURCE_ID: int = 0

## Number of columns/rows in the grass atlas (8x8 = 64 tiles total)
const FLOOR_ATLAS_COLS: int = 8

## TileSet source ID for wall tiles (TX Tileset Wall, source 1)
const WALL_SOURCE_ID: int = 1

## Atlas coordinate for the solid stone wall tile (source 1, tile 2:3, fully opaque)
const WALL_ATLAS_COORD: Vector2i = Vector2i(2, 3)

## Reference to the DungeonGenerator node
var dungeon_generator: Node = null


func _ready() -> void:
	dungeon_generator = get_node_or_null("../DungeonGenerator")

	if dungeon_generator == null:
		push_error("DungeonTileRenderer: Could not find DungeonGenerator node")
		return

	dungeon_generator.generation_complete.connect(_on_generation_complete)


## Called when dungeon generation completes. Clears the map and repaints tiles.
func _on_generation_complete(success: bool, _room_count: int, _cell_count: int) -> void:
	if not success:
		return
	clear()
	_render_dungeon()


## Iterates over all placed rooms and writes tiles for every meta-cell.
func _render_dungeon() -> void:
	if dungeon_generator == null:
		return

	var placed_rooms: Array = dungeon_generator.placed_rooms
	if placed_rooms.is_empty():
		return

	# meta_grid maps Vector2i world-position → bool (true = floor, false = wall)
	var meta_grid: Dictionary = {}

	for placement in placed_rooms:
		var meta_room: MetaRoom = placement.room
		for y in range(meta_room.height):
			for x in range(meta_room.width):
				var cell: MetaCell = meta_room.get_cell(x, y)
				if cell == null:
					continue
				var world_pos: Vector2i = placement.get_cell_world_pos(x, y)
				# BLOCKED = wall, everything else = walkable floor
				meta_grid[world_pos] = cell.cell_type != MetaCell.CellType.BLOCKED

	var floor_count: int = 0
	var wall_count: int = 0

	for meta_pos: Vector2i in meta_grid:
		var is_floor: bool = meta_grid[meta_pos]
		var base: Vector2i = meta_pos * CELLS_PER_META

		for dy in range(CELLS_PER_META):
			for dx in range(CELLS_PER_META):
				var tile_pos: Vector2i = base + Vector2i(dx, dy)
				if is_floor:
					set_cell(tile_pos, FLOOR_SOURCE_ID, _floor_atlas_coord(tile_pos))
					floor_count += 1
				else:
					set_cell(tile_pos, WALL_SOURCE_ID, WALL_ATLAS_COORD)
					wall_count += 1

	print("DungeonTileRenderer: %d floor tiles, %d wall tiles" % [floor_count, wall_count])


## Returns a deterministic grass atlas coordinate for subtle floor variation.
## Uses a position hash to avoid stripe artefacts.
func _floor_atlas_coord(tile_pos: Vector2i) -> Vector2i:
	var hash_val: int = (tile_pos.x * 1619 + tile_pos.y * 31337) & 0x7FFFFFFF
	var index: int = hash_val % (FLOOR_ATLAS_COLS * FLOOR_ATLAS_COLS)
	return Vector2i(index % FLOOR_ATLAS_COLS, index / FLOOR_ATLAS_COLS)
