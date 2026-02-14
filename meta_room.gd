class_name MetaRoom
extends Resource

## Represents a room template that can be placed on the meta grid
## Contains a pattern of meta tiles

## Room identifier
@export var room_name: String = ""

## Width and height of the room
@export var width: int = 3
@export var height: int = 3

## The layout of the room as a 2D array of MetaTileType
## Array[Array[MetaTileType]]
@export var layout: Array = []

## Weight for random selection (higher = more likely)
@export var weight: float = 1.0

## Minimum number of this room type in the dungeon
@export var min_count: int = 0

## Maximum number of this room type in the dungeon (-1 = unlimited)
@export var max_count: int = -1

func _init(p_name: String = "", p_width: int = 3, p_height: int = 3):
	room_name = p_name
	width = p_width
	height = p_height
	_initialize_layout()

## Initialize empty layout
func _initialize_layout() -> void:
	layout = []
	for y in range(height):
		var row = []
		for x in range(width):
			row.append(null)
		layout.append(row)

## Set a tile type at a specific position in the room
func set_tile(x: int, y: int, tile_type: MetaTileType) -> void:
	if x >= 0 and x < width and y >= 0 and y < height:
		layout[y][x] = tile_type

## Get a tile type at a specific position
func get_tile(x: int, y: int) -> MetaTileType:
	if x >= 0 and x < width and y >= 0 and y < height:
		return layout[y][x]
	return null

## Check if room can be placed at position in grid
func can_place_at(grid: Array, grid_width: int, grid_height: int, x: int, y: int) -> bool:
	# Check if room fits
	if x + width > grid_width or y + height > grid_height:
		return false
	
	if x < 0 or y < 0:
		return false
	
	# Check if all cells are empty or compatible
	for dy in range(height):
		for dx in range(width):
			var grid_cell = grid[y + dy][x + dx]
			var room_cell = layout[dy][dx]
			
			# If room cell is defined (not null), grid cell must be null
			if room_cell != null and grid_cell != null:
				return false
	
	return true

## Place this room on the grid at the specified position
func place_on_grid(grid: Array, x: int, y: int) -> bool:
	if not can_place_at(grid, len(grid[0]), len(grid), x, y):
		return false
	
	# Place the room tiles
	for dy in range(height):
		for dx in range(width):
			var room_cell = layout[dy][dx]
			if room_cell != null:
				grid[y + dy][x + dx] = room_cell
	
	return true
